# Mahalla Daftar

Mahalla do'konlari uchun qarz daftari (UZ/RU). Har bir do'kon o'z hisobiga kiradi va faqat o'z yozuvlarini ko'radi. Muddatli to'lov (rassrochka) jadvali bilan.

Live: https://multicloudeng.github.io/Mahalla-daftar/

## Stack
- Frontend: bitta `index.html` (vanilla JS), PWA: telefon ekraniga o'rnatiladi
- Backend: Supabase (PostgreSQL + Auth)
- Xavfsizlik: Row Level Security, har bir qatorda `owner_id = auth.uid()`; `(id, owner_id)` composite foreign key boshqa do'kon mijoziga yozuv bog'lashni bloklaydi

## Ma'lumotlar modeli
| Jadval | Nima saqlaydi |
|---|---|
| `customers` | mijozlar, telefon, qarz limiti |
| `transactions` | har bir qarz (`debt`) va to'lov (`pay`); muddatli to'lovga tegishli bo'lsa `installment_id` |
| `installments` | muddatli to'lov: mahsulot, narx, boshlang'ich to'lov, oylar soni, boshlanish sanasi |
| `settings` | do'kon nomi, karta raqami, til |

Oylik jadval saqlanmaydi, har safar hisoblanadi: `(narx − boshlang'ich) / oylar`, 1 000 so'mga yaxlitlanadi, qoldiq oxirgi oyga qo'shiladi. Har bir to'lov eng eski to'lanmagan oyni yopadi.

## Sozlash (bir marta)
1. supabase.com → New project.
2. **SQL Editor** → New query → `supabase/schema.sql` ni joylab **Run**.
3. **Authentication → URL Configuration** → Site URL: `https://multicloudeng.github.io/Mahalla-daftar/`
4. Test paytida: **Authentication → Sign In / Providers → Email** → "Confirm email" ni o'chirsangiz, ro'yxatdan o'tgan zahoti kiradi.
5. **Project Settings → API** dan `Project URL` va `anon` (yoki `publishable`) key ni oling va `config.js` ga yozing.
   `service_role` / secret key ni hech qachon frontendga qo'ymang.

## Rejalar
- FastAPI servis: Telegram bot orqali avtomatik eslatmalar (muddati o'tganda)
- Click/Payme to'lov havolasi
