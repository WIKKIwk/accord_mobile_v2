# Google Drive — pastki navigatsiya o‘lchamlari (ADB o‘lchovi)

Ma’lumot **haqiqiy qurilmada** `adb` orqali olingan: **Redmi Note 11** (`2201117TG`, `spes_global`), Google Drive paketi `com.google.android.apps.docs`, asosiy oyna `NavigationActivity`.

O‘lchov vaqti: UIAutomator dump + `dumpsys window` (loyihadagi agent sessiyasi).

---

## 1. Qurilma va tizim

| Parametr | Qiymat |
|----------|--------|
| Ekran (fizik) | **1080 × 2400** px |
| `wm density` | **440** (Android `densityDpi`) |
| dp skalasi | **1 dp ≈ 2.75 px** (`px × 160 / 440`) |
| Konfiguratsiya (dumpsys) | `sw392dp`, `w392dp`, `h791dp`, `440dpi`, `-nav/h` (3-tugmali navigatsiya) |

### Ilova oynasi (`mAppBounds`)

`Rect(0, 93 - 1080, 2270)`:

| Zona | Balandlik (px) | ≈ dp |
|------|------------------|------|
| Status bar (yuqori inset) | **93** | **~33.8** |
| Ilova kontenti (yuqoridan pastgacha) | **2270 − 93 = 2177** | **~791** (config `h791dp` bilan mos) |
| Tizim **NavigationBar0** (pastki) | **2400 − 2270 = 130** | **~47.3** |

**Xulosa:** Drive kontenti **tizim navigatsiya panelidan yuqorida** tugaydi (`y = 2270`); ilova ildiz `FrameLayout` dumpda **`[0,0][1080,2177]`** — bu **status bar ostidagi** kontent maydoni (2177 = 2270 − 93 emas… tekshiruv: 2270 − 93 = 2177 ✓).

---

## 2. Drive ichki pastki navigatsiya (`bottom_navigation`)

**Resource id:** `com.google.android.apps.docs:id/bottom_navigation`  
**Klass:** `FrameLayout`  
**To‘liq panel:** **`[0,2093][1080,2177]`**

| O‘lcham | px | ≈ dp |
|---------|-----|------|
| Kenglik | 1080 | ~392.7 |
| **Balandlik** | **2177 − 2093 = 84** | **~30.5** |

### To‘rtta tab (har biri `menu_navigation_*`)

Har bir slot **`270 × 84` px** (~**98.2 × 30.5** dp); `270 × 4 = 1080`.

| Tab | `resource-id` | `bounds` (l,t,r,b) |
|-----|---------------|---------------------|
| Home | `menu_navigation_home` | `[0,2093][270,2177]` |
| Starred | `menu_navigation_starred` | `[270,2093][540,2177]` |
| Shared | `menu_navigation_shared` | `[540,2093][810,2177]` |
| Files | `menu_navigation_drives` | `[810,2093][1080,2177]` |

### Material `navigation_bar_item_*` (birinchi tab namunasi)

- **`navigation_bar_item_content_container`:** `[58,2110][212,2177]` → **154 × 67** px (~**56 × 24.4** dp)
- **`navigation_bar_item_icon_view`:** `[102,2121][168,2177]` → **66 × 56** px (~**24 × 20.4** dp)

---

## 3. Ichki navigatsiya + qurilma navigatsiya tug‘malari (birgalikda)

Bu bo‘limda **Google Drive ichki pastki paneli** va **Android tizim navigatsiyasi** (3 tugma: orqaga / uy / ilovalar) **bir vertikal zanjirda** qanday joylashgani va qanday **qisqartiriladigan balandlik** borligi hisoblangan.

### 3.1. Ikki turdagi koordinata

| Tizim | Tushuncha |
|-------|-----------|
| **Oyna-ichki (UIAutomator)** | Ilova ildizi **`[0,0][1080,2177]`** — status bar bu ro‘yxatga kirmaydi; `y` pastga qarab o‘sadi, pastki chekka **`y = 2177`**. |
| **Displey (global)** | Butun ekran **`1080 × 2400`**. `dumpsys` dagi **`mAppBounds=Rect(0, 93 - 1080, 2270)`**: ilova chizadigan pastki chegarasi **`y = 2270`**, undan pastda tizim paneli. |

**O‘tkazish:** oyna-ichki `y` → global `Y` = **`93 + y`**.

### 3.2. Vertikal stek (ekran **pastidan** yuqoriga)

Displeyda `Y` o‘sishi pastdan yuqoriga: eng pastki qatlam — tizim navigatsiyasi.

| Qatlam | Global `Y` oralig‘i | Balandlik (px) | ≈ dp |
|--------|---------------------|----------------|------|
| **1. Tizim navigatsiya** (`NavigationBar0`, 3 tugma) | **`2270 … 2400`** | **130** | **~47.3** |
| **2. Drive `bottom_navigation`** | **`2186 … 2270`** | **84** | **~30.5** |

Hisob: ichki panel **`[0,2093][1080,2177]`** → global boshlanishi **`93 + 2093 = 2186`**, tugashi **`93 + 2177 = 2270`**.

```text
 (Y pastga qarab o‘sadi: 0 — ekran yuqorisi, 2400 — pastki chek)

Y = 93    ┌─────────────────────────────┐
          │  kontent + FAB (window y: 0…2093 → global Y: 93…2186)
Y = 2186  ├─────────────────────────────┤  ← Drive bottom_navigation (84 px)
Y = 2270  ├─────────────────────────────┤  ← tizim 3 tugma (130 px)
Y = 2400  └─────────────────────────────┘
```

### 3.3. Birgalikdagi “pastki chrome” balandligi

| Nima | px | ≈ dp |
|------|-----|------|
| Faqat Drive ichki `bottom_navigation` | **84** | **~30.5** |
| Faqat tizim navigatsiya | **130** | **~47.3** |
| **Ikkalasi ketma-ket (umumiy)** | **84 + 130 = 214** | **~77.8** |

Bu **214 px** — foydalanuvchi ko‘zida ekran pastidan **scroll kontent tugashi kerak bo‘lgan “qattiq” zonaning** taxminiy balandligi: avvalo Drive bandlari, ostida tizim tug‘malari.

### 3.4. Flutter / loyiha bilan bog‘lash

- **`MediaQuery.viewPadding.bottom`** (yoki loyihadagi `dockSystemBottomInset`) odatda **faqat tizim zonasini** ifodalaydi — shu qurilmada **~130 px**.
- O‘zingizning **`NavigationBar` / dock balandligingiz** (masalan theme **64 dp** ≈ **176 px** @440dpi) shu **130 px ustiga** qo‘shiladi — umumiy “pastdan zaxira” Drive’dagi **214 px** dan katta chiqadi, agar sizning ichki nav Drive’dan balandroq bo‘lsa.

---

## 4. FAB (floating action)

| Element | `resource-id` | `bounds` | O‘lcham (px) | ≈ dp |
|---------|---------------|----------|--------------|------|
| Kichik (scanner) | `scanner_fab` | `[882,1631][1036,1785]` | **154 × 154** | **~56 × 56** |
| Asosiy blok (Compose ichki `View`) | — | `[816,1829][1036,2049]` | **220 × 220** | **~80 × 80** |
| `fab_compose_view` konteyner | `fab_compose_view` | `[772,1829][1080,2093]` | 308 × 264 | ~112 × 96 |

**Asosiy FAB pastki cheti → `bottom_navigation` yuqori cheti:**  
`2093 − 2049 = **44 px**` ≈ **`16 dp`**.

---

## 5. Drive vs Flutter Material 3 (eskiz solishtirish)

- Drive pastki bar **~84 px (~30.5 dp)** — bu **Flutter `NavigationBar` theme 64 dp** dan pastroq; Drive kompaktroq M3/nav variantiga yaqin.
- Tizim 3-tugmali zona alohida **~130 px (~47 dp)** — ilova ichki nav undan **yuqorida** joylashgan.
- FAB va ichki nav orasidagi vertikal bo‘shliq bu o‘lchovda **~44 px (~16 dp)** atrofida.

---

## 6. Qayta o‘lchash (loyihada)

```bash
adb shell monkey -p com.google.android.apps.docs -c android.intent.category.LAUNCHER 1
adb shell uiautomator dump /sdcard/drive_dump.xml
adb pull /sdcard/drive_dump.xml .
adb shell dumpsys window windows | rg 'NavigationActivity|mAppBounds|NavigationBar0'
```

Eslatma: MIUI baʼzan `uiautomator dump` da tema fayli bo‘yicha stderr ga stack trace chiqaradi; dump fayl yine ham yoziladi.

---

## 7. Cheklovlar

- Qiymatlar **bitta qurilma + bitta Drive versiyasi + bitta til/layout** uchun; yangilanish yoki katta ekran boshqacha bo‘lishi mumkin.
- Bu **Google’ning rasmiy dizayn tokenlari emas**, faqat **runtime UI hierarxiyasi va oyna insetlari**.
