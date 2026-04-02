# AI English Learning App - Hugging Face Direct API

Ung dung Flutter hoc tieng Anh thong qua nhan dien do vat bang camera. Ung dung chup anh, gui truc tiep den API tren Hugging Face Space de phan tich, sau do hien thi:

- Tu tieng Anh
- Phien am IPA
- Nghia tieng Viet
- Cau vi du
- Huong dan phat am
- Tinh nang phat am (Text-to-Speech)

## Yeu cau he thong

- Flutter SDK >= 3.11.1
- Android Studio / Xcode
- Ket noi Internet

## Cai dat

### 1. Cau hinh moi truong

Tao file `.env` trong root project (hoac copy tu `.env.example`) va dien thong tin Supabase:

```env
HF_ANALYZE_ENDPOINT=https://minh-4t-english-analyze.hf.space/analyze-image
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_BUCKET=btl
SUPABASE_TABLE=flashcards
```

### 2. Cai dependencies va chay app

```bash
flutter pub get
flutter run
```

## API endpoint dang su dung

Endpoint phan tich anh duoc doc tu bien `HF_ANALYZE_ENDPOINT` trong file `.env`.

## Kien truc hien tai

```text
Flutter App
  -> HTTP POST (multipart image)
Hugging Face Space API
  -> JSON ket qua nhan dien
Flutter App
  -> hien thi ket qua + luu Supabase
```

## Permissions (Android)

Da duoc cau hinh trong `android/app/src/main/AndroidManifest.xml`:

- `CAMERA`: Truy cap camera
- `READ_EXTERNAL_STORAGE`: Doc gallery
- `WRITE_EXTERNAL_STORAGE`: Luu anh tam
- `INTERNET`: Goi API

## Troubleshooting

### Loi khong goi duoc API

- Kiem tra endpoint Hugging Face co hoat dong
- Kiem tra ket noi Internet
- Thu lai voi anh nhe hon

### Loi Supabase

- Kiem tra gia tri trong `.env`
- Kiem tra bucket/table da ton tai va dung ten

## Cau truc du an

```text
Cardify/
|- lib/
|- android/
|- ios/
|- web/
|- .env.example
|- pubspec.yaml
|- README.md
```

## Dependencies chinh (Flutter)

- `camera`
- `image_picker`
- `http`
- `flutter_tts`
- `supabase_flutter`
- `flutter_dotenv`

## License

MIT
