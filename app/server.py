"""
WareTrack WMS Web Server and REST API
"""

import http.server
import socketserver
import json
import os
import urllib.parse
from engine import init_db, get_db_connection, StockMovementEngine

PORT = 5050
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

class WMSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        try:
            super().__init__(*args, directory=STATIC_DIR, **kwargs)
        except TypeError:
            super().__init__(*args, **kwargs)

    def _set_headers(self, status=200, content_type='application/json'):
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(204)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path.startswith('/api/'):
            try:
                conn = get_db_connection()
                cursor = conn.cursor()

                if path == '/api/dashboard':
                    # KPI summaries
                    val = cursor.execute("SELECT SUM(total_cost_value) as cost_val, SUM(total_retail_value) as retail_val, SUM(total_units) as total_units FROM v_stock_valuation").fetchone()
                    low_stock_count = cursor.execute("SELECT count(*) as c FROM v_low_stock").fetchone()['c']
                    pending_shipments = cursor.execute("SELECT count(*) as c FROM v_pending_shipments").fetchone()['c']
                    overdue_pos = cursor.execute("SELECT count(*) as c FROM v_overdue_purchase_orders").fetchone()['c']
                    wh_count = cursor.execute("SELECT count(*) as c FROM warehouse WHERE is_active='Y'").fetchone()['c']
                    prod_count = cursor.execute("SELECT count(*) as c FROM product WHERE is_active='Y'").fetchone()['c']

                    # Recent transactions
                    recent_tx = cursor.execute("""
                        SELECT st.*, p.sku, p.product_name, w.warehouse_code, wl.location_code
                        FROM stock_transaction st
                        JOIN product p ON p.product_id = st.product_id
                        JOIN warehouse w ON w.warehouse_id = st.warehouse_id
                        LEFT JOIN warehouse_location wl ON wl.location_id = st.location_id
                        ORDER BY st.transaction_id DESC
                        LIMIT 10
                    """).fetchall()

                    low_stock_items = cursor.execute("SELECT * FROM v_low_stock").fetchall()
                    valuation = cursor.execute("SELECT * FROM v_stock_valuation").fetchall()

                    res = {
                        "metrics": {
                            "total_cost_value": val['cost_val'] or 0,
                            "total_retail_value": val['retail_val'] or 0,
                            "total_units": val['total_units'] or 0,
                            "low_stock_count": low_stock_count,
                            "pending_shipments": pending_shipments,
                            "overdue_pos": overdue_pos,
                            "warehouse_count": wh_count,
                            "product_count": prod_count
                        },
                        "low_stock_items": [dict(r) for r in low_stock_items],
                        "valuation": [dict(r) for r in valuation],
                        "recent_transactions": [dict(r) for r in recent_tx]
                    }
                    self._set_headers(200)
                    self.wfile.write(json.dumps(res).encode())

                elif path == '/api/inventory':
                    inv = cursor.execute("""
                        SELECT i.inventory_id, i.product_id, i.warehouse_id, i.location_id,
                               w.warehouse_code, w.warehouse_name,
                               wl.zone_type, wl.location_code,
                               p.sku, p.product_name, pc.category_name,
                               i.qty_on_hand, i.qty_reserved,
                               (i.qty_on_hand - i.qty_reserved) AS qty_available,
                               p.reorder_level, p.unit_cost, p.unit_price,
                               (i.qty_on_hand * p.unit_cost) AS stock_value,
                               i.updated_at
                        FROM inventory i
                        JOIN warehouse w ON w.warehouse_id = i.warehouse_id
                        JOIN product p ON p.product_id = i.product_id
                        JOIN product_category pc ON pc.category_id = p.category_id
                        JOIN warehouse_location wl ON wl.location_id = i.location_id
                        ORDER BY w.warehouse_code, p.sku
                    """).fetchall()
                    self._set_headers(200)
                    self.wfile.write(json.dumps([dict(r) for r in inv]).encode())

                elif path == '/api/products':
                    prods = cursor.execute("""
                        SELECT p.*, pc.category_code, pc.category_name
                        FROM product p
                        JOIN product_category pc ON pc.category_id = p.category_id
                        ORDER BY p.sku
                    """).fetchall()
                    self._set_headers(200)
                    self.wfile.write(json.dumps([dict(r) for r in prods]).encode())

                elif path == '/api/warehouses':
                    whs = cursor.execute("SELECT * FROM warehouse WHERE is_active='Y'").fetchall()
                    locs = cursor.execute("""
                        SELECT wl.*, w.warehouse_code
                        FROM warehouse_location wl
                        JOIN warehouse w ON w.warehouse_id = wl.warehouse_id
                        WHERE wl.is_active='Y'
                    """).fetchall()
                    self._set_headers(200)
                    self.wfile.write(json.dumps({
                        "warehouses": [dict(r) for r in whs],
                        "locations": [dict(r) for r in locs]
                    }).encode())

                elif path == '/api/purchase-orders':
                    pos = cursor.execute("""
                        SELECT po.*, s.supplier_name, s.supplier_code, w.warehouse_code, w.warehouse_name,
                               e.first_name || ' ' || e.last_name AS created_by_name
                        FROM purchase_order po
                        JOIN supplier s ON s.supplier_id = po.supplier_id
                        JOIN warehouse w ON w.warehouse_id = po.warehouse_id
                        LEFT JOIN employee e ON e.employee_id = po.created_by
                        ORDER BY po.po_id DESC
                    """).fetchall()

                    lines = cursor.execute("""
                        SELECT pl.*, p.sku, p.product_name, p.unit_of_measure
                        FROM po_line pl
                        JOIN product p ON p.product_id = pl.product_id
                    """).fetchall()

                    line_map = {}
                    for l in lines:
                        po_id = l['po_id']
                        if po_id not in line_map:
                            line_map[po_id] = []
                        line_map[po_id].append(dict(l))

                    res = []
                    for po in pos:
                        d = dict(po)
                        d['lines'] = line_map.get(po['po_id'], [])
                        res.append(d)

                    self._set_headers(200)
                    self.wfile.write(json.dumps(res).encode())

                elif path == '/api/sales-orders':
                    sos = cursor.execute("""
                        SELECT so.*, c.customer_name, c.customer_code, w.warehouse_code, w.warehouse_name,
                               e.first_name || ' ' || e.last_name AS created_by_name
                        FROM sales_order so
                        JOIN customer c ON c.customer_id = so.customer_id
                        JOIN warehouse w ON w.warehouse_id = so.warehouse_id
                        LEFT JOIN employee e ON e.employee_id = so.created_by
                        ORDER BY so.so_id DESC
                    """).fetchall()

                    lines = cursor.execute("""
                        SELECT sl.*, p.sku, p.product_name, p.unit_of_measure
                        FROM so_line sl
                        JOIN product p ON p.product_id = sl.product_id
                    """).fetchall()

                    line_map = {}
                    for l in lines:
                        so_id = l['so_id']
                        if so_id not in line_map:
                            line_map[so_id] = []
                        line_map[so_id].append(dict(l))

                    res = []
                    for so in sos:
                        d = dict(so)
                        d['lines'] = line_map.get(so['so_id'], [])
                        res.append(d)

                    self._set_headers(200)
                    self.wfile.write(json.dumps(res).encode())

                elif path == '/api/transfers':
                    xfers = cursor.execute("""
                        SELECT st.*, wf.warehouse_code AS from_warehouse_code, wt.warehouse_code AS to_warehouse_code
                        FROM stock_transfer st
                        JOIN warehouse wf ON wf.warehouse_id = st.from_warehouse_id
                        JOIN warehouse wt ON wt.warehouse_id = st.to_warehouse_id
                        ORDER BY st.transfer_id DESC
                    """).fetchall()
                    lines = cursor.execute("""
                        SELECT stl.*, p.sku, p.product_name, fl.location_code AS from_location_code, tl.location_code AS to_location_code
                        FROM stock_transfer_line stl
                        JOIN product p ON p.product_id = stl.product_id
                        JOIN warehouse_location fl ON fl.location_id = stl.from_location_id
                        JOIN warehouse_location tl ON tl.location_id = stl.to_location_id
                    """).fetchall()
                    l_map = {}
                    for l in lines:
                        tid = l['transfer_id']
                        if tid not in l_map:
                            l_map[tid] = []
                        l_map[tid].append(dict(l))

                    res = []
                    for x in xfers:
                        d = dict(x)
                        d['lines'] = l_map.get(x['transfer_id'], [])
                        res.append(d)
                    self._set_headers(200)
                    self.wfile.write(json.dumps(res).encode())

                elif path == '/api/transactions':
                    txs = cursor.execute("""
                        SELECT st.*, p.sku, p.product_name, w.warehouse_code, w.warehouse_name,
                               wl.location_code, e.first_name || ' ' || e.last_name AS employee_name
                        FROM stock_transaction st
                        JOIN product p ON p.product_id = st.product_id
                        JOIN warehouse w ON w.warehouse_id = st.warehouse_id
                        LEFT JOIN warehouse_location wl ON wl.location_id = st.location_id
                        LEFT JOIN employee e ON e.employee_id = st.employee_id
                        ORDER BY st.transaction_id DESC
                        LIMIT 100
                    """).fetchall()
                    self._set_headers(200)
                    self.wfile.write(json.dumps([dict(r) for r in txs]).encode())

                elif path == '/api/employees':
                    emps = cursor.execute("SELECT employee_id, employee_code, first_name, last_name, job_title FROM employee WHERE is_active='Y'").fetchall()
                    self._set_headers(200)
                    self.wfile.write(json.dumps([dict(r) for r in emps]).encode())

                else:
                    self._set_headers(404)
                    self.wfile.write(json.dumps({"error": "Not Found"}).encode())

                conn.close()
            except Exception as e:
                self._set_headers(500)
                self.wfile.write(json.dumps({"error": str(e)}).encode())
        else:
            # Fall back to serving static files or index.html
            if path == '/' or not os.path.exists(os.path.join(STATIC_DIR, path.lstrip('/'))):
                self.path = '/index.html'
            return super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else b'{}'
        try:
            data = json.loads(body.decode())
        except Exception:
            data = {}

        try:
            if path == '/api/receive-stock':
                po_line_id = int(data.get('po_line_id'))
                location_id = int(data.get('location_id'))
                qty = float(data.get('qty'))
                employee_id = int(data.get('employee_id', 1))
                receipt_id = data.get('receipt_id')
                if receipt_id:
                    receipt_id = int(receipt_id)

                res = StockMovementEngine.receive_stock(po_line_id, location_id, qty, employee_id, receipt_id)
                self._set_headers(200)
                self.wfile.write(json.dumps(res).encode())

            elif path == '/api/ship-stock':
                so_line_id = int(data.get('so_line_id'))
                location_id = int(data.get('location_id'))
                qty = float(data.get('qty'))
                employee_id = int(data.get('employee_id', 1))
                carrier = data.get('carrier', 'FedEx')
                tracking = data.get('tracking_number')

                res = StockMovementEngine.ship_stock(so_line_id, location_id, qty, employee_id, carrier=carrier, tracking_no=tracking)
                self._set_headers(200)
                self.wfile.write(json.dumps(res).encode())

            elif path == '/api/adjust-stock':
                product_id = int(data.get('product_id'))
                warehouse_id = int(data.get('warehouse_id'))
                location_id = int(data.get('location_id'))
                qty_change = float(data.get('qty_change'))
                reason = data.get('reason_code', 'MANUAL_ADJUSTMENT')
                notes = data.get('notes', '')
                employee_id = int(data.get('employee_id', 1))

                res = StockMovementEngine.adjust_stock(product_id, warehouse_id, location_id, qty_change, employee_id, reason, notes)
                self._set_headers(200)
                self.wfile.write(json.dumps(res).encode())

            elif path == '/api/transfer-stock':
                from_wh = int(data.get('from_warehouse_id'))
                to_wh = int(data.get('to_warehouse_id'))
                product_id = int(data.get('product_id'))
                from_loc = int(data.get('from_location_id'))
                to_loc = int(data.get('to_location_id'))
                qty = float(data.get('qty'))
                employee_id = int(data.get('employee_id', 1))
                notes = data.get('notes', '')

                res = StockMovementEngine.transfer_stock(from_wh, to_wh, product_id, from_loc, to_loc, qty, employee_id, notes)
                self._set_headers(200)
                self.wfile.write(json.dumps(res).encode())

            elif path == '/api/sql':
                # Interactive SQL Console
                query = data.get('query', '').strip()
                if not query:
                    raise ValueError("Query cannot be empty.")
                
                # Check for write safety unless requested
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute(query)
                if query.upper().startswith("SELECT") or query.upper().startswith("PRAGMA") or query.upper().startswith("EXPLAIN"):
                    rows = cursor.fetchall()
                    cols = [d[0] for d in cursor.description] if cursor.description else []
                    res_data = [dict(r) for r in rows]
                    self._set_headers(200)
                    self.wfile.write(json.dumps({
                        "columns": cols,
                        "rows": res_data,
                        "count": len(res_data)
                    }).encode())
                else:
                    conn.commit()
                    self._set_headers(200)
                    self.wfile.write(json.dumps({
                        "message": f"Query executed successfully. Rows affected: {cursor.rowcount}"
                    }).encode())
                conn.close()

            elif path == '/api/reset':
                init_db(reset=True)
                self._set_headers(200)
                self.wfile.write(json.dumps({"status": "success", "message": "Database reset & reseeded successfully."}).encode())

            else:
                self._set_headers(404)
                self.wfile.write(json.dumps({"error": "Endpoint not found"}).encode())
        except Exception as e:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": str(e)}).encode())

def run_server(port=PORT):
    init_db()
    socketserver.TCPServer.allow_reuse_address = True
    server_address = ('', port)
    httpd = socketserver.TCPServer(server_address, WMSRequestHandler)
    print(f"🚀 WareTrack WMS Running at http://localhost:{port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        httpd.server_close()

if __name__ == '__main__':
    run_server()
