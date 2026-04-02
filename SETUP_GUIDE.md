# Huong dan cau hinh - Cardify (Hugging Face direct)

## Buoc 1: Chuan bi moi truong

- Flutter SDK
- Android Studio hoac Xcode
- Ket noi Internet on dinh

## Buoc 2: Cau hinh bien moi truong

Tao file `.env` tai root project (copy tu `.env.example`):

```env
HF_ANALYZE_ENDPOINT=https://minh-4t-english-analyze.hf.space/analyze-image
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_BUCKET=btl
SUPABASE_TABLE=flashcards
```

## Buoc 3: Cai dat dependencies

```bash
flutter pub get
```

## Buoc 4: Chay ung dung

```bash
flutter run
```

## Buoc 5: Kiem tra endpoint AI

Ung dung doc endpoint Hugging Face tu bien `HF_ANALYZE_ENDPOINT` trong `.env`.

Khong can chay server backend local.

## Troubleshooting

### Loi goi API

1. Kiem tra endpoint Hugging Face co dang online.
2. Kiem tra mang Internet tren thiet bi.
3. Thu chup anh nhe hon va ro hon.

### Loi luu Supabase

1. Kiem tra `.env` da co day du 4 bien.
2. Kiem tra bucket va table tren Supabase.
3. Kiem tra RLS policy neu co bat.

### Loi quyen tren Android

1. Vao Settings -> Apps -> Cardify.
2. Cap quyen Camera va Storage (neu he dieu hanh yeu cau).

## Ghi chu

- App hien tai khong phu thuoc backend Python rieng.
- Toan bo luong phan tich anh di truc tiep tu Flutter den Hugging Face API.
