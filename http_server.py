#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
HTTP 文件服务器启动脚本 (Enhanced)
用途：在局域网内提供文件下载服务，支持目录浏览、搜索、以及自动生成脚本执行命令
"""

import os
import sys
import socket
import argparse
import urllib.parse
import html
import io
import ipaddress
from http.server import HTTPServer, SimpleHTTPRequestHandler
import mimetypes

try:
    import netifaces
except ImportError:
    netifaces = None

# ----------------------------------------------------------------------
# 嵌入式 Web 界面资源 (HTML/CSS/JS)
# ----------------------------------------------------------------------

PAGE_TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>文件服务器 - {cwd}</title>
    <style>
        :root {{
            --primary-color: #2563eb;
            --bg-color: #f8fafc;
            --card-bg: #ffffff;
            --text-main: #1e293b;
            --text-muted: #64748b;
            --border-color: #e2e8f0;
            --accent-green: #10b981;
            --accent-amber: #f59e0b;
        }}
        
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        
        body {{
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            line-height: 1.5;
            padding: 2rem;
        }}

        .container {{
            max-width: 1000px;
            margin: 0 auto;
        }}

        header {{
            margin-bottom: 2rem;
            display: flex;
            flex-direction: column;
            gap: 1rem;
        }}

        h1 {{
            font-size: 1.5rem;
            font-weight: 600;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }}
        
        .nav-path {{
            font-family: monospace;
            background: var(--card-bg);
            padding: 0.5rem 1rem;
            border-radius: 6px;
            border: 1px solid var(--border-color);
            color: var(--primary-color);
        }}

        .search-bar {{
            margin-bottom: 1.5rem;
        }}
        
        input[type="text"].search-input {{
            width: 100%;
            padding: 0.75rem 1rem;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            font-size: 1rem;
            transition: all 0.2s;
        }}
        
        input[type="text"].search-input:focus {{
            outline: none;
            border-color: var(--primary-color);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
        }}

        /* List View Styles */
        .file-list {{
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
        }}

        .file-item {{
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 1rem;
            display: flex;
            flex-direction: column;
            gap: 0.75rem;
            transition: background-color 0.2s;
        }}
        
        .file-item:hover {{
            background-color: #f8fafc;
            border-color: #cbd5e1;
        }}

        .file-main-row {{
            display: flex;
            align-items: center;
            gap: 1rem;
            width: 100%;
        }}

        .icon {{
            font-size: 1.25rem;
            flex-shrink: 0;
            width: 2rem;
            text-align: center;
        }}

        .file-info {{
            flex: 1;
            min-width: 0;
            display: flex;
            flex-direction: column;
        }}

        .filename {{
            font-weight: 600;
            color: var(--text-main);
            text-decoration: none;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            font-size: 1rem;
        }}
        
        .filename:hover {{
            color: var(--primary-color);
            text-decoration: underline;
        }}
        
        .meta {{
            font-size: 0.75rem;
            color: var(--text-muted);
        }}

        /* Command Display Area */
        .command-area {{
            background: #f1f5f9;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            padding: 0.5rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin-top: 0.25rem;
        }}

        .cmd-label {{
            font-size: 0.75rem;
            font-weight: 600;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            background: #e2e8f0;
            padding: 0.2rem 0.4rem;
            border-radius: 4px;
            white-space: nowrap;
        }}

        .command-input {{
            flex: 1;
            background: transparent;
            border: none;
            font-family: monospace;
            font-size: 0.85rem;
            color: #334155;
            width: 100%;
        }}
        
        .command-input:focus {{
            outline: none;
        }}

        .actions {{
            display: flex;
            gap: 0.5rem;
            flex-shrink: 0;
            align-items: flex-start;
        }}

        .btn {{
            border: 1px solid var(--border-color);
            background: white;
            color: var(--text-main);
            padding: 0.35rem 0.75rem;
            border-radius: 4px;
            font-size: 0.8rem;
            cursor: pointer;
            transition: all 0.2s;
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
            font-weight: 500;
            white-space: nowrap;
        }}

        .btn:hover {{
            background: #f1f5f9;
            border-color: #cbd5e1;
        }}

        .btn-primary {{
            background: var(--primary-color);
            color: white;
            border-color: var(--primary-color);
        }}
        
        .btn-primary:hover {{
            background: #1d4ed8;
            border-color: #1d4ed8;
        }}

        .toast {{
            position: fixed;
            top: 2rem;
            left: 50%;
            transform: translateX(-50%) translateY(-200%); /* Start hidden above */
            background: #10b981;
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 50px;
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
            transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            z-index: 9999; /* Ensure high z-index */
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 0.5rem;
            opacity: 0; /* Hidden by default */
            pointer-events: none;
        }}
        
        .toast.show {{
            transform: translateX(-50%) translateY(0);
            opacity: 1;
        }}

        @media (max-width: 640px) {{
            body {{ padding: 1rem; }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📂 文件服务器</h1>
            <div class="nav-path">{cwd}</div>
        </header>

        <div class="search-bar">
            <input type="text" id="searchInput" class="search-input" placeholder="🔍 搜索文件..." onkeyup="filterFiles()">
        </div>

        <div class="file-list" id="fileList">
            {file_list_html}
        </div>
    </div>

    <div id="toast" class="toast">
        <span>✓</span> <span id="toastMsg">命令已复制</span>
    </div>

    <script>
        const currentHost = window.location.host;
        const protocol = window.location.protocol;

        // On load, populate all command inputs
        document.addEventListener('DOMContentLoaded', () => {{
            const inputs = document.querySelectorAll('.command-input[data-path]');
            inputs.forEach(input => {{
                const path = input.getAttribute('data-path');
                const type = input.getAttribute('data-type');
                input.value = generateCommand(type, path);
            }});
        }});

        function generateCommand(type, path) {{
            const url = `${{protocol}}//${{currentHost}}${{path}}`;
            
            if (type === 'shell') {{
                return `curl -fsSL ${{url}} | bash`;
            }} else if (type === 'ps1') {{
                return `irm ${{url}} | iex`;
            }} else if (type === 'python') {{
                return `curl -fsSL ${{url}} | python3`;
            }} else if (type === 'pipe') {{
                const filename = path.split('/').pop();
                return `curl -fsSL ${{url}} -o /tmp/${{filename}} && chmod +x /tmp/${{filename}} && /tmp/${{filename}}`;
            }}
            return url;
        }}

        function copyFromInput(btn) {{
            // Find sibling input
            const container = btn.closest('.command-area');
            const input = container.querySelector('.command-input');
            
            input.select();
            input.setSelectionRange(0, 99999); // For mobile devices

            // Try navigator.clipboard first
            if (navigator.clipboard) {{
                navigator.clipboard.writeText(input.value).then(() => {{
                    showToast(`复制成功！`);
                }}).catch(err => {{
                    console.warn('Clipboard API failed, converting to fallback:', err);
                    fallbackCopy(input);
                }});
            }} else {{
                fallbackCopy(input);
            }}
        }}

        function fallbackCopy(inputElement) {{
            try {{
                const successful = document.execCommand('copy');
                const msg = successful ? '复制成功' : '复制失败';
                showToast(msg);
            }} catch (err) {{
                console.error('Fallback copy failed', err);
                showToast('无法复制');
            }}
        }}

        function showToast(msg) {{
            const toast = document.getElementById('toast');
            const msgEl = document.getElementById('toastMsg');
            if (msgEl) msgEl.textContent = msg;
            
            toast.classList.add('show');
            
            // Clear previous timeout if exists (simple debounce)
            if (toast.timeoutId) clearTimeout(toast.timeoutId);
            
            toast.timeoutId = setTimeout(() => {{
                toast.classList.remove('show');
            }}, 2000);
        }}

        function filterFiles() {{
            const input = document.getElementById('searchInput');
            const filter = input.value.toLowerCase();
            const items = document.getElementsByClassName('file-item');

            for (let i = 0; i < items.length; i++) {{
                const filename = items[i].querySelector('.filename').textContent;
                if (filename.toLowerCase().indexOf(filter) > -1) {{
                    items[i].style.display = "flex";
                }} else {{
                    items[i].style.display = "none";
                }}
            }}
        }}
    </script>
</body>
</html>
"""

FILE_ITEM_TEMPLATE = """
<div class="file-item">
    <div class="file-main-row">
        <div class="icon">{icon}</div>
        <div class="file-info">
            <a href="{href}" class="filename" title="{name}">{display_name}</a>
            <div class="meta">{meta_info}</div>
        </div>
        <div class="actions">
            {actions}
        </div>
    </div>
    {command_area}
</div>
"""

# ----------------------------------------------------------------------
# 核心逻辑
# ----------------------------------------------------------------------

class BetterHTTPRequestHandler(SimpleHTTPRequestHandler):
    
    def list_directory(self, path):
        """Helper to produce a directory listing (absent index.html)."""
        try:
            list_dir = os.scandir(path)
        except OSError:
            self.send_error(404, "No permission to list directory")
            return None
            
        list_dir = list(list_dir)
        list_dir.sort(key=lambda a: a.name.lower())
        
        display_path = urllib.parse.unquote(self.path, errors='surrogatepass')
        
        items = []
        
        # 添加 "返回上一级"
        if self.path != '/':
            parent_path = os.path.dirname(display_path.rstrip('/'))
            if not parent_path: parent_path = '/'
            items.append(FILE_ITEM_TEMPLATE.format(
                icon="..",
                href=parent_path,
                name="Parent Directory",
                display_name=".. (返回上一级)",
                meta_info="",
                actions="",
                command_area=""
            ))

        for entry in list_dir:
            fullname = entry.name
            displayname = linkname = fullname
            
            command_area_html = ""
            actions_list = []
            
            quoted_path = urllib.parse.quote(self.path + linkname)
            quoted_path = quoted_path.replace('//', '/')

            if entry.is_dir():
                displayname = name = fullname + "/"
                linkname = fullname + "/"
                icon = "📁"
                meta_info = "Directory"
                actions_list.append(f'<a href="{urllib.parse.quote(linkname)}" class="btn">打开</a>')
            else:
                icon = "📄"
                try:
                    size = entry.stat().st_size
                    size_str = self.sizeof_fmt(size)
                except OSError:
                    size_str = "-"
                meta_info = size_str
                
                # 下载按钮
                actions_list.append(f'<button class="btn" onclick="window.location.href=\'{quoted_path}\'">下载</button>')

                # 智能命令生成区域
                ext = os.path.splitext(fullname)[1].lower()
                
                # Helper to create a command row
                def make_cmd_row(label, ctype):
                    return f'''
                    <div class="command-area">
                        <span class="cmd-label">{label}</span>
                        <input type="text" class="command-input" readonly value="Loading..." data-type="{ctype}" data-path="{quoted_path}">
                        <button class="btn btn-primary" onclick="copyFromInput(this)">复制</button>
                    </div>
                    '''

                if ext == '.sh':
                    # Standard Bash
                    command_area_html += make_cmd_row('Bash', 'shell')
                    # Interactive / Pipe
                    command_area_html += make_cmd_row('Interactive', 'pipe')
                elif ext == '.ps1':
                    command_area_html += make_cmd_row('PowerShell', 'ps1')
                elif ext == '.py':
                    command_area_html += make_cmd_row('Python', 'python')

            actions = "".join(actions_list)

            items.append(FILE_ITEM_TEMPLATE.format(
                icon=icon,
                href=urllib.parse.quote(linkname),
                name=html.escape(displayname),
                display_name=html.escape(displayname),
                meta_info=meta_info,
                actions=actions,
                command_area=command_area_html
            ))

        encoded = PAGE_TEMPLATE.format(
            cwd=html.escape(display_path),
            file_list_html="\n".join(items)
        ).encode('utf-8', 'surrogateescape')
        
        f = io.BytesIO()
        f.write(encoded)
        f.seek(0)
        
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        return f


        
        f = io.BytesIO()
        f.write(encoded)
        f.seek(0)
        
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        return f

    def sizeof_fmt(self, num, suffix='B'):
        for unit in ['','Ki','Mi','Gi','Ti','Pi','Ei','Zi']:
            if abs(num) < 1024.0:
                return "%3.1f%s%s" % (num, unit, suffix)
            num /= 1024.0
        return "%.1f%s%s" % (num, 'Yi', suffix)


def unique_keep_order(values):
    """去重并保留原始顺序。"""
    seen = set()
    result = []
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result


def is_private_ip(ip):
    """检查是否是适合作为局域网访问入口的 IPv4 私有地址。"""
    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return False
    return (
        addr.version == 4
        and addr.is_private
        and not addr.is_loopback
        and not addr.is_link_local
        and not addr.is_multicast
        and not addr.is_unspecified
    )


def is_virtual_interface(interface):
    """过滤 Docker、WSL、虚拟机、VPN 等虚拟网卡。"""
    name = interface.lower()
    if name in ("lo", "lo0") or name.startswith("lo:"):
        return True
    virtual_keywords = (
        "loopback", "docker", "veth", "br-", "bridge", "virbr",
        "wsl", "vethernet", "hyper-v", "vmware", "virtualbox", "vbox",
        "tailscale", "zerotier", "tun", "tap", "wg", "npcap",
    )
    return any(keyword in name for keyword in virtual_keywords)


def get_socket_primary_ip():
    """通过系统路由表获取默认出站网卡 IP，不会真正发送数据。"""
    for target in ("223.5.5.5", "8.8.8.8", "1.1.1.1"):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect((target, 80))
                ip = s.getsockname()[0]
                if is_private_ip(ip):
                    return ip
        except OSError:
            continue
    return None


def get_hostname_ips():
    ips = []
    try:
        hostname = socket.gethostname()
        for addr_info in socket.getaddrinfo(hostname, None, socket.AF_INET):
            ip = addr_info[4][0]
            if is_private_ip(ip):
                ips.append(ip)
    except OSError:
        pass
    return unique_keep_order(ips)


def get_default_interfaces():
    if netifaces is None:
        return []

    """获取默认路由所在网卡，通常就是实际连接局域网的网卡。"""
    interfaces = []
    try:
        gateways = netifaces.gateways()
        default_gateway = gateways.get("default", {}).get(netifaces.AF_INET)
        if default_gateway and len(default_gateway) >= 2:
            interfaces.append(default_gateway[1])
    except Exception:
        pass
    return unique_keep_order(interfaces)


def get_interface_ips(interface):
    if netifaces is None:
        return []

    """读取指定网卡上的 IPv4 私有地址。"""
    ips = []
    try:
        addrs = netifaces.ifaddresses(interface)
    except Exception:
        return ips
    for addr_info in addrs.get(netifaces.AF_INET, []):
        ip = addr_info.get("addr", "")
        if is_private_ip(ip):
            ips.append(ip)
    return ips


def get_local_ips(include_virtual=False):
    if netifaces is None:
        ips = []
        socket_ip = get_socket_primary_ip()
        if socket_ip:
            ips.append(socket_ip)
        ips.extend(get_hostname_ips())
        return unique_keep_order(ips)

    """获取本机局域网 IP 地址，默认只显示主网卡，避免 Docker/WSL 虚拟地址刷屏。"""
    ips = []

    if include_virtual:
        try:
            for interface in netifaces.interfaces():
                ips.extend(get_interface_ips(interface))
        except Exception:
            pass
        socket_ip = get_socket_primary_ip()
        if socket_ip:
            ips.insert(0, socket_ip)
        return unique_keep_order(ips)

    for interface in get_default_interfaces():
        if not is_virtual_interface(interface):
            ips.extend(get_interface_ips(interface))

    socket_ip = get_socket_primary_ip()
    if socket_ip:
        ips.insert(0, socket_ip)

    if ips:
        return unique_keep_order(ips)

    # 没有默认路由时，退一步显示非虚拟网卡上的私有地址。
    try:
        for interface in netifaces.interfaces():
            if not is_virtual_interface(interface):
                ips.extend(get_interface_ips(interface))
    except Exception:
        pass

    return unique_keep_order(ips)

def get_first_available_port(start_port):
    """获取可用端口"""
    port = start_port
    while True:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('0.0.0.0', port))
            return port
        except OSError:
            port += 1

def print_banner(port, ips, directory):
    """打印启动信息"""
    print("\n" + "="*60)
    print(f" ✨ HTTP 增强版文件服务器已启动")
    print(f" 📂 根目录: {os.path.abspath(directory)}")
    print(f" 🔌 端口: {port}")
    print("-" * 60)
    print(" 🌐 访问地址:")
    if not ips:
        print(f"    http://localhost:{port}")
    for ip in ips:
        print(f"    http://{ip}:{port}")
    print("    （默认只显示主网卡地址；如需显示 Docker/WSL 等虚拟网卡，请加 --all-ips）")
    print("\nPRO TIP: 在浏览器中打开上述地址，即可享受现代化 UI 与自动命令生成功能！")
    print("="*60 + "\n")

def main():
    parser = argparse.ArgumentParser(description='Enhanced HTTP File Server')
    parser.add_argument('--port', '-p', type=int, default=7878, help='端口号 (默认: 7878)')
    parser.add_argument('--directory', '-d', type=str, default='.', help='服务目录')
    parser.add_argument('--all-ips', action='store_true', help='显示所有私有地址，包括 Docker/WSL/虚拟网卡')
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.directory):
        print(f"❌ 错误: 目录 {args.directory} 不存在")
        sys.exit(1)
        
    os.chdir(args.directory)
    
    port = get_first_available_port(args.port)
    ips = get_local_ips(include_virtual=args.all_ips)
    
    print_banner(port, ips, args.directory)
    
    server_address = ('', port)
    httpd = HTTPServer(server_address, BetterHTTPRequestHandler)
    
    print("✅ 服务正在前台运行")
    print("👉 按 Ctrl+C 强制停止服务器")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 收到 Ctrl+C，正在强制退出...")
        sys.stdout.flush()
        sys.stderr.flush()
        os._exit(0)

if __name__ == "__main__":
    main()
