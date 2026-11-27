# Tayyorlov va material ta’minoti uchun ombor rejasi

2026-11-27. Mini RS ERP va Accord Mobile V2 uchun amalga oshirish taklifi.

Bitta omborda tayyorlovga kelgan xomashyo va master chiqargan rulon yonma-yon turishi mumkin. Har bir partiya bo‘yicha xodim uning joyi va mas’ulini, hozir nimaga ajratilganini va qaysi amalni bajarishi mumkinligini ko‘rsin. Ichki yoki tashqi kelib chiqishi partiya tarixida saqlanadi.

`Seriyo` ERPdagi mavjud tayyorlov xomashyosi guruhidir. Tayyorlov masteri o‘ziga biriktirilgan Seriyo materialini o‘zi mas’ul bo‘lgan omborga mustaqil kirim qila oladi. Bu vakolat umumiy omborda ham materialning omborga bog‘lanishi doirasida amal qiladi.

## Hozir ishlaydigan qismlar

- Master `Tayyorlov hisobi → Rulonlar`da o‘zi chiqargan, tarozida tasdiqlangan rulonlarni ko‘radi va paddonga biriktiradi. Bu jurnal rulonning dastlabki kirimini ham saqlaydi. Joriy omborda qolgan miqdor alohida inventar hisobidan olinadi.
- Ta’minotchining `Mahsulotlar → tanlash → + → Paddonga biriktirish` yo‘li V2 va ERPning `main` tarmog‘ida bor. Ikkala rol uchun paddon tanlash oynasi va biriktirishni saqlash mantiqi umumiy. Ta’minotchida ombor, material guruhi, rulonning bo‘shligi va mavjud paddonga huquq tekshiriladi.
- Ta’minotchi paddondan chiqarib jo‘natgan mos partiyani master transferni qabul qilgach sarflashi mumkin. Oddiy transfer bilan kelgan xomashyo uchun ombor qoldig‘i bilan sarfga yaroqli qoldiq farq qilishi mumkin. Paddonni ko‘rish va undan chiqim qilish hozir yaratuvchining roli va hisobiga bog‘langan.
- Tekshiruv paytida V2 `4e6e14e3`, ERP `38e1c690` edi. Samsung’dagi faol bazada oxirgi migratsiya `0210`. Ta’minotchining yangi biriktirish amali `0212`ga tayanadi.

## Amalga oshirish tartibi

### 1. ERPda partiyaning vazifasini va har bir rolning vakolatini belgilash

| Amal | Tayyorlov masteri | Material ta’minotchi |
| --- | --- | --- |
| Tayyorlovga xomashyo berish va qabul qilish | Biriktirilgan Seriyoni o‘zi kirim qiladi yoki yuborilgan partiyani tayyorlov ombori yoki sexiga qabul qiladi | Vakolatli ombor va guruhdan yetkazib beradi |
| Ishlab chiqarish | Buyurtmadagi sarfni va o‘zi chiqargan rulonni tasdiqlaydi | O‘z omboridagi tayyor rulon va uning mavjud holatini ko‘radi |
| Rulonni paddonga biriktirish | O‘zi chiqargan mos rulonlarni amaldagi qoidalar bilan biriktiradi | Vakolatli ombordagi va guruhdagi bo‘sh tayyor rulonni biriktiradi |
| Tayyor paddonni keyingi mas’ulga berish | Tasarrufidagi paddonni topshiradi yoki o‘ziga yuborilganini qabul qiladi | Paddonni qabul qiladi va vakolati doirasida sexga yetkazadi |

Mavjud ombor qoldig‘idagi partiyaga uning joriy vazifasi bog‘lanadi. Tayyorlovga qabul qilingan miqdor **Tayyorlov uchun xomashyo**ga, tasdiqlangan ishlab chiqarishdan chiqqan rulon **Tayyor rulonlar**ga kiradi. Boshqa sexlarga mo‘ljallangan hamda vazifasi hali aniqlanmagan material **Barchasi**da ko‘rinadi. **Barchasi** umumiy ro‘yxat bo‘lib, undagi kilogramm boshqa bo‘limlarning ustiga qo‘shilmaydi.

Vazifani o‘zgartirishda partiyaning kelib chiqishi, QR kodi va tarixi saqlanadi. Masalan, kecha chiqarilgan rulon bugun qayta ishlashga qabul qilinsa, bugungi ombor ro‘yxatida tayyorlov xomashyosiga o‘tadi. Kechagi ishlab chiqarish jurnalida esa chiqarilgan rulon sifatida qoladi. Faqat bir qismi ajratilsa, mavjud partiyani bo‘lish amali orqali ajratilgan miqdor asl partiyaga bog‘lanadi.

Umumiy omborda master o‘ziga topshirilgan materialni ko‘ra olishini alohida tekshirish kerak. Bugungi qoida boshqa biriktirilgan xodimlarning material guruhlariga ham bog‘liq. Ko‘rish, sarflash va boshqa joyga jo‘natish uchun server xodimning aynan shu amal, ombor va materialga joriy huquqini tekshiradi.

### 2. Ta’minotchidan mastergacha bo‘lgan kirim va sarfni ulash

- Ta’minotchi mavjud partiyani tanlaydi va **Tayyorlovga berish** amalida qabul qiluvchi ombor yoki sexni ko‘rsatadi. Boshqa omborga jo‘natilsa, mavjud transfer orqali boradi. Bitta umumiy ombor ichida shu partiyaga tayyorlov uchun ajratilgani va kim qabul qilgani qayd etiladi.
- Qabul yakunlanganda ERP oddiy transferdan ham, paddondan yechilgan materialdan ham mavjud qoldiq yozuvini tayyorlov sarfiga bog‘laydi. Ikkinchi kirim yoki yana shuncha kilogramm yaratilmaydi. Yo‘ldagi material **Kiruvchi**da kuzatiladi. Bekor qilingan topshirish qoldiqni yana avvalgi holatida ishlatishga ochadi.
- **Sarfga tayyor** deb ko‘rsatilgan kilogramm va **Sarfni tasdiqlash** amali bir xil partiyalarni hisoblasin. Omborda turgan, lekin paddonda yoki boshqa buyurtmaga band materialning holati ko‘rinsin. Master mavjud buyurtma sahifasida ombor, material va miqdorni ko‘rib sarfni tasdiqlaydi. Buning uchun mavjud sarf va partiyalardan miqdor yechish mantiqi ishlatiladi.
- O‘lchangan yangi rulon alohida qoldiq va o‘z QR kodi bilan ishlab chiqarish jurnaliga tushadi. Buyurtma yoki batch mavjud bo‘lsa, uning sarfi va natijasi o‘sha kontekstdan kuzatiladi. Bir buyurtmadan bir nechta rulon chiqishi oldin yozilgan sarfni takrorlamasligi kerak.

### 3. Paddonga biriktirish va butun paddonni topshirish

- V2 tanlov oynasi va ERPdagi mavjud biriktirish amali qayta ishlatiladi. Ta’minotchi biriktirishi mumkin bo‘lgan rulonlar oldindan ko‘rsatiladi. Shu omborda mos paddoni bo‘lmasa, **Yangi paddonga biriktirish** bo‘sh paddonni yaratish va tanlangan rulonlarni joylashni bitta amalda bajaradi.
- Paddon yaratuvchisi tarixda saqlanadi. Joriy mas’ul va topshirish holati alohida yuritiladi. **Paddonni topshirish → Qabul qilish** butun paddon, uning QR kodi va ichidagi birliklarni birga olib o‘tadi. Bir qatordan qisman yechib olish uchun bugungi chiqim amali ishlatiladi. Taroziga qo‘yilmagan birliklar dona bilan yuritilsa, ularga taxminiy kilogramm yozilmaydi.
- Jo‘natish va qabul qilishda vakolat butun tarkib bo‘yicha tekshiriladi. Bir ombor ichida qabul qilish joriy mas’ulni almashtiradi. Omborlararo jo‘natishda paddon va tarkibi bitta transferga bog‘lanadi. Ochiq topshirish paytida rulonlarni yechish yoki qayta biriktirish bloklanadi. Qabul yoki bekor qilish paddon, joylashuv va qoldiqni bitta tranzaksiyada yangilaydi. Paddon mas’uli ombordan olinayotgan paytda qolgan yuk boshqa vakolatli mas’ulga topshirilishi hisobga olinadi.
- Masterga ruxsat berilgan buyurtmaga bog‘langan rulonni yig‘ish va ta’minotchining faqat bo‘sh rulonni yig‘ish qoidalari saqlanadi. Yakuniy yozishda server holatni qayta tekshiradi. Mavjud takroriy so‘rov kaliti va bir rulonning faqat bitta faol paddonda turishi qoidasidan foydalaniladi. Tarixda biriktirish, yechish, topshirish va qabul qilishni bajargan xodim ko‘rinadi.

### 4. V2 sahifalarini ishga moslashtirish

| Ekran | O‘zgarish |
| --- | --- |
| Master → **Ombor** | Tanlangan omborda **Tayyorlov uchun xomashyo** va **Tayyor rulonlar**. Hozirgi **Ishlab chiqarilgan homashyolar** kartasi shu omborning tayyor rulonlarini ochadi. **Transferlar** orqali master kiruvchi yukni qabul qilish va chiquvchini kuzatish sahifasiga kira oladi. |
| Master → **Tayyorlov hisobi** | **Buyurtmalar**, **Batchlar**, **Rulonlar**, **Paddonlar** ishlab chiqarish tarixi va kuzatuvi uchun ishlatiladi. Rulon tafsilotida uning hozirgi ombori yoki paddoni vakolat doirasida ochiladi. |
| Ta’minotchi → **Joylashtirish va transfer → Mahsulotlar** | Bir ombor ichida **Barchasi**, **Tayyorlov uchun**, **Tayyor rulonlar** filtrlari. **State’lar**, **Kiruvchi**, **Chiquvchi** o‘z joyida ishlaydi. **Homashyo biriktirish** yorlig‘i buyurtma amalini aniq ifodalashi uchun **Buyurtmaga biriktirish** deb ko‘rsatiladi. |
| Ikkala rol → **Paddonlar** | Mavjud ro‘yxat, QR skaneri va paddon tafsiloti ishlatiladi. Tanlangan rulon uchun **+ → Paddonga biriktirish**, yig‘ilgan paddon uchun **Topshirish**, qabul qiluvchida **Qabul qilish** ko‘rinadi. |

Filtr serverda sahifalashdan oldin qo‘llanadi. Tanlangan ombor ro‘yxatdan tafsilotga va orqaga o‘tilganda saqlanadi. Ombor, filtr yoki hisob almashganda oldingi belgilangan qatorlar tozalanadi. Ish vaqtida boshqa xodim rulonni band qilsa, foydalanuvchi yangilangan holat va sababni ko‘radi.

### 5. Eski qoldiqni moslashtirish, sinov va chiqarish

Avval `0210` darajasidagi sinov bazasida migratsiyalarni tartib bilan qo‘llash, jumladan mavjud `0212`ni tekshirish kerak. Yangi qoidalar uchun keyingi migratsiya qo‘shiladi. Eski partiyalar tasdiqlangan ishlab chiqarish kirimi yoki tayyorlovga qabul yozuvi bilan aniqlanadi. Dalili noaniq yoki qarama-qarshi yozuvlar umumiy inventarda saqlanadi va vakolatli xodim ularni ajrata oladi. QR kodisiz qayd etilgan kilogramm kirimi o‘z birligida saqlanadi. Ilgari sarflanadigan partiyalar ham sinovda solishtiriladi.

| Qabul sinovi | Kutiladigan natija |
| --- | --- |
| Ta’minotchi oddiy transfer bilan 100 kg yuboradi, master qabul qilib 60 kg sarflaydi | Qabulgacha sarf yopiq. Qabuldan keyin 100 kg tayyorlovda, sarfdan keyin 40 kg qoladi. Takror tasdiq miqdorni o‘zgartirmaydi. Shu sinov paddondan yechilgan material bilan ham o‘tadi. |
| Bir omborda tashqi xomashyo, master chiqargan rulon va boshqa sex materiali bor | Ikkala rol o‘z vakolatidagi partiyalarni kerakli bo‘limdan topadi. Rulonni qayta ishlashga topshirish uning joriy bo‘limini almashtiradi, tarix va QR saqlanadi. |
| Master yig‘gan paddonni ta’minotchi qabul qilib sexga beradi | Qabul qiluvchi aynan o‘sha QR va tarkibni ko‘radi. Bekor qilish avvalgi mas’ul va qoldiqni tiklaydi. Begona ombor yoki ruxsatsiz guruhga amal rad etiladi. |
| Ikkala xodim bir rulonni bir vaqtda biriktiradi yoki aloqa uzilib so‘rov takrorlanadi | Bitta faol biriktirish saqlanadi. Javob qayta olinganda yangi paddon, sarf yoki transfer yaratilmaydi. |
| Eski baza va eski V2 bilan yangilanish | Ombor va material bo‘yicha kilogramm, paddonlardagi dona va QRlar yangilashdan oldingi qiymatlarga teng. Eski V2 kirim va transferni davom ettiradi. Yangi V2 tegishli server imkoniyati mavjud bo‘lganda yangi amallarni ochadi. |

Shu mezonlar o‘tgach, avval ERP va migratsiyalar, keyin V2 chiqariladi. Yakuniy tekshiruv bir umumiy omborda ikkala rol bilan **yetkazish → qabul → sarf → rulon chiqarish → paddonga biriktirish → sexga topshirish** zanjirini to‘liq o‘tkazishdan iborat.

## Ishni boshlash uchun kod manbalari

- ERPda [ombor qoldig‘i](../../../../mini_rs_erp/src/db/postgres_preparation_parts/stock_snapshot.rs), [tayyorlov sarfi](../../../../mini_rs_erp/src/db/postgres_preparation_parts/consume.rs) va [qabul qilingan partiyani bog‘lash](../../../../mini_rs_erp/src/db/postgres_preparation/paddons_parts/received_preparation_lot.rs).
- ERPda [master uchun biriktirish](../../../../mini_rs_erp/src/db/postgres_preparation/paddons/attachments.rs), [ta’minotchi uchun tanlov](../../../../mini_rs_erp/src/db/postgres_preparation/paddons/inventory_attachments.rs), [paddon vakolati](../../../../mini_rs_erp/src/db/postgres_preparation/paddons.rs) va [ikkala rolning integratsiya sinovi](../../../../mini_rs_erp/tests/raw_material_paddons.rs).
- V2da [master ombori](../../../lib/src/features/preparation/presentation/preparation_screen_forms.dart), [ishlab chiqarish jurnali](../../../lib/src/features/preparation/presentation/preparation_production_screen.dart), [umumiy inventar](../../../lib/src/features/inventory/presentation/inventory_movements_screen.dart) va [mavjud paddon tanlash oynasi](../../../lib/src/features/preparation/presentation/preparation_production_paddon_picker.dart).
