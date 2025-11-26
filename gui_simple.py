#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib, Pango
import subprocess
import os
import psutil
import time
import re
import sys
import stat

SCRIPT_FILENAME = "auto_off.sh" 
SCRIPT_PATH = os.path.expanduser(f"~/{SCRIPT_FILENAME}")
LOG_FILE = os.path.expanduser("~/auto_off.log")

class ScriptManagerGUI(Gtk.Window):
    def __init__(self):
        Gtk.Window.__init__(self, title="DESLIGAR POR INATIVIDADE")
        self.set_border_width(15)
        self.set_default_size(400, 380)
        self.set_position(Gtk.WindowPosition.CENTER_ALWAYS)
        self.connect("destroy", Gtk.main_quit)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        self.add(vbox)

        lbl_title = Gtk.Label(label="<span size='x-large' weight='bold'>CONFIGUAR TEMPO DE DESLIGAMENTO</span>")
        lbl_title.set_use_markup(True)
        vbox.pack_start(lbl_title, False, False, 5)

        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(15)
        vbox.pack_start(grid, False, False, 0)

        lbl_delay = Gtk.Label(label="Desligar PC após (min):")
        lbl_delay.set_halign(Gtk.Align.END)
        self.entry_delay = Gtk.Entry()
        self.entry_delay.set_placeholder_text("Ex: 10")
        grid.attach(lbl_delay, 0, 0, 1, 1)
        grid.attach(self.entry_delay, 1, 0, 1, 1)

        lbl_tela = Gtk.Label(label="Desligar Tela após (min):")
        lbl_tela.set_halign(Gtk.Align.END)
        self.entry_tela = Gtk.Entry()
        self.entry_tela.set_placeholder_text("Ex: 1")
        grid.attach(lbl_tela, 0, 1, 1, 1)
        grid.attach(self.entry_tela, 1, 1, 1, 1)

        self.load_config_from_script()

        self.button_apply = Gtk.Button(label="Salvar e Reiniciar Serviço")
        self.button_apply.get_style_context().add_class("suggested-action")
        self.button_apply.connect("clicked", self.on_apply_clicked)
        vbox.pack_start(self.button_apply, False, False, 5)

        vbox.pack_start(Gtk.HSeparator(), False, False, 5)

        hbox_switch = Gtk.Box(spacing=10)
        hbox_switch.set_halign(Gtk.Align.CENTER)
        
        lbl_status_t = Gtk.Label(label="<b>Estado do Serviço:</b>")
        lbl_status_t.set_use_markup(True)
        self.switch = Gtk.Switch()
        self.switch.connect("notify::active", self.on_switch_toggled)
        
        hbox_switch.pack_start(lbl_status_t, False, False, 0)
        hbox_switch.pack_start(self.switch, False, False, 0)
        vbox.pack_start(hbox_switch, False, False, 0)

        self.status_label = Gtk.Label(label="Verificando...")
        self.status_label.set_ellipsize(Pango.EllipsizeMode.END)
        vbox.pack_start(self.status_label, False, False, 0)

        self.check_permissions()
        self.refresh_ui_state()

        GLib.timeout_add_seconds(2, self.refresh_ui_state)

    def check_permissions(self):
        if os.path.exists(SCRIPT_PATH):
            st = os.stat(SCRIPT_PATH)
            os.chmod(SCRIPT_PATH, st.st_mode | stat.S_IEXEC)

    def get_script_process(self):
        for proc in psutil.process_iter(['pid', 'cmdline']):
            try:
                cmdline = proc.info['cmdline']
                if cmdline and SCRIPT_FILENAME in " ".join(cmdline):
                    if "python" not in cmdline[0] and "nano" not in cmdline[0]: 
                        return proc
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        return None

    def kill_script(self):
        proc = self.get_script_process()
        if proc:
            try:
                proc.terminate()
                proc.wait(timeout=3)
            except psutil.TimeoutExpired:
                try:
                    proc.kill()
                    proc.wait(timeout=1)
                except:
                    pass
            except psutil.NoSuchProcess:
                pass

        timeout = 0
        while self.get_script_process() and timeout < 20:
            time.sleep(0.1)
            timeout += 1
        return True

    def run_script(self):
        if not os.path.isfile(SCRIPT_PATH):
            self.update_status("ERRO: Arquivo .sh não encontrado!", error=True)
            return

        if self.get_script_process():
            return

        try:
            subprocess.Popen(
                ["nohup", SCRIPT_PATH],
                stdout=open(LOG_FILE, 'a'),
                stderr=subprocess.STDOUT,
                cwd=os.path.dirname(SCRIPT_PATH),
                preexec_fn=os.setpgrp
            )
            time.sleep(0.5)
            self.update_status("Serviço iniciado com sucesso.")
        except Exception as e:
            self.update_status(f"Erro ao iniciar: {e}", error=True)

    def refresh_ui_state(self):
        is_running = bool(self.get_script_process())
        self.switch.handler_block_by_func(self.on_switch_toggled)
        self.switch.set_active(is_running)
        self.switch.handler_unblock_by_func(self.on_switch_toggled)
        
        if is_running:
            self.status_label.set_markup("<span foreground='green'>● Monitoramento Ativo</span>")
        else:
            self.status_label.set_markup("<span foreground='red'>● Serviço Parado</span>")
        return True

    def update_status(self, text, error=False):
        color = "#ff4444" if error else "#4488ff"
        self.status_label.set_markup(f"<span foreground='{color}'>{text}</span>")

    def load_config_from_script(self):
        if not os.path.exists(SCRIPT_PATH):
            return
        try:
            with open(SCRIPT_PATH, 'r') as f:
                content = f.read()
                match_pc = re.search(r'^LIMITE_PC=(\d+)', content, re.MULTILINE)
                match_tela = re.search(r'^LIMITE_TELA=(\d+)', content, re.MULTILINE)
                if match_pc:
                    minutes = int(match_pc.group(1)) // 60
                    self.entry_delay.set_text(str(minutes))
                if match_tela:
                    minutes = int(match_tela.group(1)) // 60
                    self.entry_tela.set_text(str(minutes))
        except Exception as e:
            print(f"Erro ao ler config: {e}")

    def save_config_to_script(self, min_pc, min_tela):
        sec_pc = int(min_pc) * 60
        sec_tela = int(min_tela) * 60
        try:
            with open(SCRIPT_PATH, 'r') as f:
                content = f.read()
            new_content = re.sub(r'^LIMITE_PC=\d+', f'LIMITE_PC={sec_pc}', content, flags=re.MULTILINE)
            new_content = re.sub(r'^LIMITE_TELA=\d+', f'LIMITE_TELA={sec_tela}', new_content, flags=re.MULTILINE)
            with open(SCRIPT_PATH, 'w') as f:
                f.write(new_content)
            return True
        except Exception as e:
            self.update_status(f"Erro ao salvar: {e}", error=True)
            return False

    def on_apply_clicked(self, button):
        min_pc = self.entry_delay.get_text()
        min_tela = self.entry_tela.get_text()
        if min_pc.isdigit() and min_tela.isdigit():
            if self.save_config_to_script(min_pc, min_tela):
                self.update_status("Reiniciando serviço...", error=False)
                while Gtk.events_pending():
                    Gtk.main_iteration()
                self.kill_script()
                time.sleep(0.5) 
                self.run_script() 
                self.refresh_ui_state()
                self.update_status("Configurações aplicadas com sucesso.")
        else:
            self.update_status("Erro: Use apenas números inteiros.", error=True)

    def on_switch_toggled(self, switch, gparam):
        if switch.get_active():
            self.run_script()
        else:
            self.kill_script()
            self.refresh_ui_state()

if __name__ == "__main__":
    if 'psutil' not in sys.modules:
        print("Instale usando: sudo apt install python3-psutil")
        sys.exit(1)
    win = ScriptManagerGUI()
    win.show_all()
    Gtk.main()
