#!/usr/bin/env bash
# Google Drive va Accord ilovasining pastki nav / FAB atrofidagi UIAutomator dumpini solishtirish.
# Talab: USB yoki wireless ADB, ikkala ilova o‘rnatilgan.
set -euo pipefail

PKG_DRIVE="com.google.android.apps.docs"
PKG_ACCORD="com.example.erpnext_stock_mobile"
TMP="${TMPDIR:-/tmp}"

dump_ui() {
  local pkg=$1
  local out=$2
  adb shell "monkey -p ${pkg} -c android.intent.category.LAUNCHER 1" >/dev/null 2>&1 || true
  sleep 2.8
  adb shell uiautomator dump "/sdcard/${out}" >/dev/null
  adb pull "/sdcard/${out}" "${TMP}/${out}" >/dev/null
  echo "  → ${TMP}/${out}"
}

echo "=== Drive (${PKG_DRIVE}) ==="
dump_ui "${PKG_DRIVE}" "drive_ui.xml"
grep -E 'bottom_navigation|fab_compose_view|scanner_fab|bounds=' "${TMP}/drive_ui.xml" | head -25 || true

echo ""
echo "=== Accord (${PKG_ACCORD}) ==="
dump_ui "${PKG_ACCORD}" "accord_ui.xml"
# BottomNavigationView, birinchi tab matni (masalan Uy), FAB "+"
grep -E 'BottomNavigation|bounds=.*\[(Uy|Bildirish|Yangi|Arxiv)|MaterialButton|bounds=' "${TMP}/accord_ui.xml" | head -35 || true

echo ""
echo "Qo‘lda: ikki dumpdagi pastki panel va tugma bounds (left,top,right,bottom) ni px da solishtiring."
echo "Drive ref: docs/google_drive_bottom_nav_measurements.md"
