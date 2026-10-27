# Mahalla Daftar

Mahalla do'konlari uchun qarz daftari (UZ/RU). Har bir do'kon o'z hisobiga kiradi va faqat o'z yozuvlarini ko'radi. Muddatli to'lov (rassrochka) jadvali bilan.

Live: https://multicloudeng.github.io/Mahalla-daftar/

## Stack
- Frontend: bitta `index.html` (vanilla JS), PWA: telefon ekraniga o'rnatiladi, oflayn o'qish rejimi
- Backend: Supabase (PostgreSQL + Auth), `supabase-js` 2.45.4 repoda (`vendor/`), CDN'ga bog'liq emas
- Xavfsizlik:
  - Row Level Security: har bir qatorda `owner_id = auth.uid()`
  - Composite foreign key'lar: boshqa do'kon mijoziga yoki boshqa mijozning rassrochkasiga yozuv bog'lab bo'lmaydi
  - Har bir do'konga yozuvlar chegarasi (trigger), summalarga yuqori chegara
  - `anon` hech narsaga kira olmaydi; `authenticated` faqat SELECT/INSERT/UPDATE/DELETE (TRUNCATE yo'q)
  - Email havolalari faqat shu telefonda so'ralgan bo'lsa yoki foydalanuvchi o'z emailini yozib tasdiqlasa qabul qilinadi

## Ma'lumotlar modeli
| Jadval | Nima saqlaydi |
|---|---|
| `customers` | mijozlar, telefon, qarz limiti |
| `transactions` | har bir qarz (`debt`) va to'lov (`pay`); rassrochkaga tegishli bo'lsa `installment_id` |
| `installments` | rassrochka: mahsulot, narx, boshlang'ich to'lov, oylar, boshlanish sanasi, oylik summa |
| `settings` | do'kon nomi, karta raqami, til |

Oylik summa rassrochka yaratilganda saqlanadi (1 000 so'mga yuqoriga yaxlitlanadi, oxirgi oy kichikroq). To'lovlar eng eski to'lanmagan oydan boshlab yopiladi. Oddiy qarzdan ortiqcha to'langan pul rassrochkaga o'tadi.

## Sozlash
1. supabase.com → New project.
2. **SQL Editor** → `supabase/schema.sql` ni joylab **Run**. Fayl qayta ishga tushirsa ham, eski bazada ham xavfsiz.
3. **Authentication → URL Configuration** → Site URL va Redirect URL: `https://multicloudeng.github.io/Mahalla-daftar/`
4. **Authentication → Emails → SMTP**: o'z pochta xizmatingizni ulang (masalan Resend). Supabase'ning standart pochtasi faqat loyiha a'zolariga xat yuboradi.
5. **Authentication → Attack Protection**: CAPTCHA (Cloudflare Turnstile) yoqish tavsiya qilinadi. **Confirm email** yoqiq qolsin.
6. `config.js` ga `Project URL` va publishable key. `service_role` / secret key hech qachon frontendga qo'yilmaydi.

## Rejalar
- FastAPI servis: Telegram bot orqali avtomatik eslatmalar
- Click/Payme to'lov havolasi
- Alohida domen (hozir `multicloudeng.github.io` boshqa sahifalar bilan umumiy)
