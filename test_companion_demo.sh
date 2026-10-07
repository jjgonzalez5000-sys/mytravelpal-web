#!/bin/bash
# Companion Demo Script — simulates driving Madrid→Zaragoza with events
# Usage: ./test_companion_demo.sh [device_serial]
# Requires: adb, device connected with Companion active in AA

ADB="adb"
[ -n "$1" ] && ADB="adb -s $1"

PACKAGE="com.mytravelpal.travel"

echo "=== MyTravelPal Companion Demo ==="
echo "Make sure Companion mode is active in the app."
echo ""

# Helper: write string to FlutterSharedPreferences via broadcast intent
# Flutter stores strings as: putString("flutter.KEY", "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu" + value) for doubles
# For booleans and longs we use the companion demo activity intent

send_demo_state() {
  local state="$1"
  $ADB shell am broadcast \
    -a "${PACKAGE}.DEMO_STATE" \
    --es state "$state" \
    --receiver-foreground 2>/dev/null
}

move_gps() {
  local lon="$1"
  local lat="$2"
  local label="$3"
  echo "  📍 GPS → $label ($lat, $lon)"
  $ADB shell geo fix "$lon" "$lat"
}

fire_notification() {
  local title="$1"
  local body="$2"
  local wlat="$3"
  local wlon="$4"
  local dlat="$5"
  local dlon="$6"
  echo "  🔔 Notif: $title"
  $ADB shell am broadcast \
    -a "${PACKAGE}.DEMO_NOTIF" \
    --es title "$title" \
    --es body "$body" \
    --ef waypointLat "$wlat" \
    --ef waypointLon "$wlon" \
    --ef destLat "$dlat" \
    --ef destLon "$dlon" \
    --receiver-foreground 2>/dev/null
}

echo "--- Fase 1: Salida de Madrid (sin eventos) ---"
move_gps -3.7038 40.4168 "Madrid centro"
sleep 4

echo ""
echo "--- Fase 2: A 30 km de Madrid — gasolinera barata ---"
move_gps -3.3000 40.5000 "A-2 km 30"
sleep 2
fire_notification \
  "⛽ Repsol · −9 ct/L" \
  "A 3 km · Desvía en Maps para repostar en la más barata de la ruta" \
  40.5100 -3.2900 \
  41.6500 -0.8900
echo "  ⏳ Esperando 6s..."
sleep 6

echo ""
echo "--- Fase 3: Corredor del Jalón — evento adverso (incendio) ---"
move_gps -2.1000 41.0000 "Guadalajara / A-2"
sleep 2
fire_notification \
  "🔥 Incendio forestal" \
  "Detectado a 18 km en tu ruta · Considera la N-II como alternativa · Desviar en Maps" \
  41.0800 -1.9500 \
  41.6500 -0.8900
echo "  ⏳ Esperando 6s..."
sleep 6

echo ""
echo "--- Fase 4: Calatayud — hora de comer (restaurante 5 min) ---"
move_gps -1.6430 41.3560 "Calatayud"
sleep 2
fire_notification \
  "🍽 El Portal del Jiloca" \
  "Menú 12€ · A 4 km · ¿Paramos a comer?" \
  41.3600 -1.6200 \
  41.6500 -0.8900
echo "  ⏳ Esperando 6s..."
sleep 6

echo ""
echo "--- Fase 5: Acercándose a Zaragoza ---"
move_gps -1.1000 41.5500 "Entrada Zaragoza"
sleep 2
fire_notification \
  "🏁 Llegando a Zaragoza" \
  "ETA 14:32 · 12 km restantes · Sin incidencias en el tramo final" \
  41.6488 -0.8891 \
  41.6488 -0.8891
echo "  ⏳ Esperando 6s..."
sleep 6

echo ""
echo "--- Fase 6: Zaragoza — destino alcanzado ---"
move_gps -0.8891 41.6488 "Zaragoza centro"
sleep 2

echo ""
echo "=== Demo completado ==="
echo "El DHU debería haber mostrado:"
echo "  ✓ Notificación gasolinera con botón Desviar"
echo "  ✓ Alerta incendio con botón Desviar"
echo "  ✓ Sugerencia restaurante"
echo "  ✓ Confirmación llegada"
