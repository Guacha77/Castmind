from __future__ import annotations
import asyncio, json, os, queue, socket, threading, time
from dataclasses import dataclass, asdict
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox

import pyttsx3
from websockets.asyncio.server import serve
from zeroconf import IPVersion, ServiceInfo, Zeroconf

try:
    import obsws_python as obs
except Exception:
    obs = None

ROOT = Path(__file__).resolve().parent
CONFIG_PATH = ROOT / "config.json"
DEFAULTS = json.loads((ROOT / "config.example.json").read_text(encoding="utf-8"))


def load_config():
    if not CONFIG_PATH.exists():
        CONFIG_PATH.write_text(json.dumps(DEFAULTS, indent=2), encoding="utf-8")
    data = DEFAULTS | json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    return data


def local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80)); return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


@dataclass
class BridgeState:
    connected_clients: int = 0
    last_character: str = "—"
    last_text: str = "Esperando Castmind…"
    last_cue: str = "normal"
    obs_status: str = "Desactivado"
    events: int = 0


class OBSController:
    def __init__(self, cfg, emit):
        self.cfg, self.emit, self.client = cfg, emit, None

    def connect(self):
        if not self.cfg.get("obs_enabled"):
            return
        if obs is None:
            self.emit("OBS: falta obsws-python")
            return
        try:
            self.client = obs.ReqClient(
                host=self.cfg["obs_host"], port=int(self.cfg["obs_port"]),
                password=self.cfg.get("obs_password", ""), timeout=3
            )
            self.emit("OBS conectado")
        except Exception as e:
            self.client = None; self.emit(f"OBS error: {e}")

    def _scene_item_id(self, source):
        if not self.client: return None
        return self.client.get_scene_item_id(self.cfg["obs_scene"], source).scene_item_id

    def set_visible(self, source, visible):
        if not self.client: return
        try:
            item = self._scene_item_id(source)
            if item is not None:
                self.client.set_scene_item_enabled(self.cfg["obs_scene"], item, visible)
        except Exception as e:
            self.emit(f"OBS visibilidad: {e}")

    def caption(self, text):
        if not self.client: return
        try:
            self.client.set_input_settings(self.cfg["caption_source"], {"text": text}, True)
        except Exception as e:
            self.emit(f"OBS subtítulo: {e}")

    def talking(self, on):
        self.set_visible(self.cfg["idle_source"], not on)
        self.set_visible(self.cfg["talking_source"], on)


class TTSEngine:
    def __init__(self, cfg, emit):
        self.cfg, self.emit = cfg, emit
        self.q = queue.Queue()
        self.thread = threading.Thread(target=self._worker, daemon=True)
        self.thread.start()

    def say(self, text, before=None, after=None):
        if self.cfg.get("tts_enabled"):
            self.q.put((text, before, after))
        else:
            if before: before()
            if after: after()

    def _worker(self):
        try:
            engine = pyttsx3.init()
            engine.setProperty("rate", int(self.cfg.get("tts_rate", 185)))
        except Exception as e:
            self.emit(f"TTS no disponible: {e}"); return
        while True:
            text, before, after = self.q.get()
            try:
                if before: before()
                engine.say(text); engine.runAndWait()
            except Exception as e:
                self.emit(f"TTS error: {e}")
            finally:
                if after: after()


class BridgeServer:
    def __init__(self, cfg, state, emit, update_ui):
        self.cfg, self.state, self.emit, self.update_ui = cfg, state, emit, update_ui
        self.loop = None; self.stop_event = None
        self.obs = OBSController(cfg, emit); self.tts = TTSEngine(cfg, emit)
        self.zeroconf = None; self.info = None

    def start(self):
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        asyncio.run(self._main())

    async def _main(self):
        self.loop = asyncio.get_running_loop(); self.stop_event = asyncio.Event()
        self.obs.connect(); self._advertise()
        host, port = self.cfg["listen_host"], int(self.cfg["port"])
        self.emit(f"Bridge escuchando en ws://{local_ip()}:{port}")
        try:
            async with serve(self._handler, host, port, ping_interval=20, ping_timeout=20, max_size=2_000_000):
                await self.stop_event.wait()
        finally:
            self._unadvertise()

    async def _handler(self, ws):
        self.state.connected_clients += 1; self.update_ui()
        try:
            async for raw in ws:
                try:
                    payload = json.loads(raw)
                except json.JSONDecodeError:
                    await ws.send(json.dumps({"ok": False, "error": "invalid_json"})); continue
                if payload.get("secret") != self.cfg.get("secret"):
                    await ws.send(json.dumps({"ok": False, "error": "unauthorized"})); continue
                await self._event(payload)
                await ws.send(json.dumps({"ok": True, "type": payload.get("type", "unknown")}))
        finally:
            self.state.connected_clients = max(0, self.state.connected_clients - 1); self.update_ui()

    async def _event(self, p):
        self.state.events += 1
        self.state.last_character = p.get("character", "Castmind")
        self.state.last_text = p.get("text", "")
        self.state.last_cue = p.get("cue", "normal")
        self.emit(f"{self.state.last_character} [{self.state.last_cue}]: {self.state.last_text}")
        self.update_ui()
        if p.get("type") == "test":
            return
        if p.get("type") != "assistant_reply":
            return
        self.obs.caption(self.state.last_text)
        self.tts.say(self.state.last_text, before=lambda: self.obs.talking(True), after=lambda: self.obs.talking(False))

    def _advertise(self):
        try:
            ip = socket.inet_aton(local_ip())
            self.zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
            self.info = ServiceInfo(
                "_castmind._tcp.local.",
                f"{self.cfg.get('advertise_name','Castmind PC')}._castmind._tcp.local.",
                addresses=[ip], port=int(self.cfg["port"]),
                properties={"version": "3", "product": "Castmind"}, server=f"{socket.gethostname()}.local."
            )
            self.zeroconf.register_service(self.info)
            self.emit("Descubrimiento automático activo")
        except Exception as e:
            self.emit(f"mDNS no disponible (puedes usar IP manual): {e}")

    def _unadvertise(self):
        try:
            if self.zeroconf and self.info: self.zeroconf.unregister_service(self.info)
            if self.zeroconf: self.zeroconf.close()
        except Exception:
            pass


class Dashboard(tk.Tk):
    def __init__(self):
        super().__init__(); self.title("Castmind Stream Bridge V3"); self.geometry("780x560"); self.minsize(680, 500)
        self.cfg = load_config(); self.state_data = BridgeState(); self.log_q = queue.Queue()
        self._style(); self._build()
        self.server = BridgeServer(self.cfg, self.state_data, self.log, self.update_cards); self.server.start()
        self.after(100, self._drain_log)

    def _style(self):
        style = ttk.Style(self)
        if "vista" in style.theme_names(): style.theme_use("vista")
        style.configure("Title.TLabel", font=("Segoe UI", 22, "bold"))
        style.configure("Big.TLabel", font=("Segoe UI", 14, "bold"))
        style.configure("Muted.TLabel", foreground="#777777")

    def _build(self):
        root = ttk.Frame(self, padding=22); root.pack(fill="both", expand=True)
        top = ttk.Frame(root); top.pack(fill="x")
        ttk.Label(top, text="CASTMIND", style="Title.TLabel").pack(side="left")
        ttk.Label(top, text="STREAM BRIDGE V3", style="Muted.TLabel").pack(side="left", padx=12, pady=(9,0))
        self.conn = ttk.Label(top, text="● 0 iPhone", style="Big.TLabel"); self.conn.pack(side="right")

        info = ttk.LabelFrame(root, text="Estado", padding=14); info.pack(fill="x", pady=(18,12))
        grid = ttk.Frame(info); grid.pack(fill="x")
        self.ip_label = ttk.Label(grid, text=f"PC: {local_ip()}:{self.cfg['port']}", style="Big.TLabel"); self.ip_label.grid(row=0,column=0,sticky="w",padx=(0,30))
        self.char_label = ttk.Label(grid, text="Personaje: —", style="Big.TLabel"); self.char_label.grid(row=0,column=1,sticky="w")
        self.cue_label = ttk.Label(grid, text="Cue: normal", style="Muted.TLabel"); self.cue_label.grid(row=1,column=1,sticky="w",pady=(4,0))
        ttk.Label(grid, text="Castmind debería encontrar este PC automáticamente en la misma Wi‑Fi.", style="Muted.TLabel").grid(row=1,column=0,sticky="w",pady=(4,0))

        last = ttk.LabelFrame(root, text="Última respuesta", padding=14); last.pack(fill="x", pady=8)
        self.last_text = tk.Text(last, height=4, wrap="word", font=("Segoe UI", 11), relief="flat", bg="#f5f5f5")
        self.last_text.pack(fill="x"); self.last_text.insert("1.0", self.state_data.last_text); self.last_text.configure(state="disabled")

        buttons = ttk.Frame(root); buttons.pack(fill="x", pady=8)
        ttk.Button(buttons, text="Abrir config.json", command=lambda: os.startfile(CONFIG_PATH)).pack(side="left")
        ttk.Button(buttons, text="Probar OBS", command=self._test_obs).pack(side="left", padx=8)
        ttk.Button(buttons, text="Copiar IP", command=lambda: self.clipboard_append(f"{local_ip()}:{self.cfg['port']}")).pack(side="left")

        log_box = ttk.LabelFrame(root, text="Actividad", padding=8); log_box.pack(fill="both", expand=True, pady=(8,0))
        self.log_text = tk.Text(log_box, height=10, wrap="word", font=("Consolas", 9), relief="flat")
        self.log_text.pack(fill="both", expand=True); self.log_text.configure(state="disabled")

    def log(self, text):
        self.log_q.put(f"[{time.strftime('%H:%M:%S')}] {text}")

    def _drain_log(self):
        while not self.log_q.empty():
            line = self.log_q.get_nowait(); self.log_text.configure(state="normal"); self.log_text.insert("end", line+"\n"); self.log_text.see("end"); self.log_text.configure(state="disabled")
        self.after(100, self._drain_log)

    def update_cards(self):
        self.after(0, self._update_cards_now)

    def _update_cards_now(self):
        s = self.state_data
        self.conn.configure(text=f"● {s.connected_clients} iPhone")
        self.char_label.configure(text=f"Personaje: {s.last_character}")
        self.cue_label.configure(text=f"Cue: {s.last_cue} · Eventos: {s.events}")
        self.last_text.configure(state="normal"); self.last_text.delete("1.0","end"); self.last_text.insert("1.0",s.last_text); self.last_text.configure(state="disabled")

    def _test_obs(self):
        if not self.cfg.get("obs_enabled"):
            messagebox.showinfo("OBS", "Activa obs_enabled en config.json y reinicia el companion."); return
        self.server.obs.caption("Castmind V3 · prueba correcta")
        self.server.obs.talking(True); self.after(700, lambda: self.server.obs.talking(False))


if __name__ == "__main__":
    Dashboard().mainloop()
