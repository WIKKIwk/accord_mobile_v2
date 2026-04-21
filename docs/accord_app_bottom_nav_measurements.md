# Accord ilovasi — pastki navigatsiya va FAB (ADB o‘lchovi)

Ma’lumot **haqiqiy qurilmada** `uiautomator dump` + `dumpsys window` orqali olingan.

| Maydon | Qiymat |
|--------|--------|
| Qurilma | Redmi Note 11 (`2201117TG`, `spes_global`) |
| Ilova | `com.example.erpnext_stock_mobile` |
| Oyna | `MainActivity` (oldinda Werka / «Omborchi» ekrani) |
| Ekran | **1080 × 2400** px, **440 dpi** (`1 dp ≈ 2.75 px`) |

---

## 1. Tizim (Drive hujjatidagi qurilma bilan bir xil)

| Parametr | px | ≈ dp |
|----------|-----|------|
| Status bar (yuqori) | **93** | ~33.8 |
| **`mAppBounds`** pastki chegara | **2270** | — |
| Tizim **NavigationBar0** (3 tugma) | **2400 − 2270 = 130** | ~47.3 |
| Flutter/oyna kontenti balandligi | **2177** (= 2270 − 93) | ~791 |

---

## 2. Ilova ichki pastki panel (native `BottomNavigationView`)

Dumpdagi asosiy konteyner: **`[0,1964][1080,2177]`** (`FrameLayout`).

| O‘lcham | px | ≈ dp |
|---------|-----|------|
| **Panel balandligi** | **2177 − 1964 = 213** | **~77.5** |
| Kenglik | 1080 | ~392.7 |

### Uchta tab (har biri **360 px** keng)

| Tab | `content-desc` | `bounds` [l,t,r,b] |
|-----|----------------|---------------------|
| Uy | `Uy` | `[0,1964][360,2177]` |
| Bildirish | `Bildirish` | `[360,1964][720,2177]` |
| Arxiv | `Arxiv` | `[720,1964][1080,2177]` |

`360 × 3 = 1080` ✓

### Material `navigation_bar_item_*` (Uy tab namunasi)

| Element | `resource-id` | `bounds` | O‘lcham (px) |
|---------|---------------|----------|----------------|
| `navigation_bar_item_icon_container` | …`icon_container` | `[92,1997][268,2085]` | **176 × 88** |
| `navigation_bar_item_active_indicator_view` | …`active_indicator_view` | `[92,1997][268,2085]` | **176 × 88** |
| `navigation_bar_item_icon_view` | …`icon_view` | `[147,2008][213,2074]` | **66 × 66** |

Eslatma: `navigation_bar_item_*_label_view` dumpda **`[0,0][0,0]`** — matn Accessibility daraxtida to‘liq joylashmagan (yoki yashirin layout); real UI da yorliqlar ko‘rinadi.

---

## 3. Asosiy «+» tugmasi (native)

Klass: **`android.widget.Button`** (Material primary).

| Atribut | Qiymat |
|---------|--------|
| `bounds` | **`[805,1748][1036,1979]`** |
| O‘lcham | **231 × 231** px ≈ **84 × 84** dp |
| O‘ng chetga masofa | 1080 − 1036 = **44** px (~16 dp) |

### FAB vs pastki panel (oqim koordinatalari)

- Pastki panel **yuqori** cheti: **y = 1964**
- FAB **pastki** cheti: **y = 1979**
- **1979 − 1964 = 15 px** (~**5.5** dp) — FAB pastki qismi panel **zonasiga** kirib turadi (ustma-ust chiqish).

---

## 4. Ichki nav + tizim tug‘malari (birgalikda)

| Qatlam | Oyna `y` | Global `Y` (= 93 + y) | Balandlik (px) |
|--------|----------|------------------------|----------------|
| Ilova dock | 1964 … 2177 | 2057 … 2270 | **213** |
| Tizim navigatsiya | — | 2270 … 2400 | **130** |

**Ketma-ket umumiy «pastki chrome»:** **213 + 130 = 343** px ≈ **124.7** dp  
(Drive bilan solishtirganda: **84 + 130 = 214** px — Accord ichki panel ancha balandroq.)

---

## 5. Google Drive (xuddi shu qurilma) bilan qisqa taqqoslash

| Ko‘rsatkich | Google Drive | Accord (bu dump) |
|-------------|--------------|------------------|
| Ichki pastki panel balandligi | **84** px (~30.5 dp) | **213** px (~77.5 dp) |
| Tab kengligi (4 vs 3) | 270 px | 360 px |
| Asosiy FAB o‘lchami | ~220 px (Compose ichki `View`) | **231** px (84 dp tugma) |
| FAB pastki ↔ nav yuqori | **+44** px bo‘shliq | **−15** px (qoplash) |
| Tizim nav | 130 px | 130 px (bir xil) |

---

## 6. Qayta o‘lchash

```bash
adb shell dumpsys window | rg 'mCurrentFocus|mFocusedApp'
adb shell uiautomator dump /sdcard/accord_dump.xml
adb pull /sdcard/accord_dump.xml .
```

**Eslatma:** Flutter yo‘lida (`EdgeToEdgeBottomSlot` + `NavigationBar`) ochilganda ierarxiya boshqacha bo‘ladi; bu dump **native dock** (`MainActivity` + `NativeDockHostView`) rejimidagi o‘lchov.

---

## 7. Cheklovlar

- Bitta ekran (Werka bosh sahifa), bitta build va bitta qurilma.
- Accessibility daraxti har doim piksel-mukammal emas (masalan, label `bounds` 0).
