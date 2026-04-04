import base64
import json
import os
import re
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from fastapi import APIRouter, FastAPI, File, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from groq import Groq
from PIL import Image
from pydantic import BaseModel, Field

load_dotenv(dotenv_path=Path(__file__).resolve().parent / ".env")

app = FastAPI(
    title="Vision Learning API",
    version="1.3.0",
    description="Nhận ảnh để học từ vựng và hỗ trợ chat giải nghĩa hành động/đồ vật",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

health_router = APIRouter(prefix="/health", tags=["health"])
vision_router = APIRouter(prefix="/ai", tags=["vision"])
chat_router = APIRouter(prefix="/chat", tags=["chat"])

REQUIRED_FIELDS = {
    "topic": "Chủ đề từ vựng",
    "word": "Từ tiếng Anh",
    "phonetic": "Phiên âm",
    "vietnamese_meaning": "Nghĩa tiếng Việt",
    "example_sentence": "Ví dụ",
    "pronunciation_guide": "Hướng dẫn phát âm",
    "word_type": "Loại từ",
}

CHAT_REQUIRED_FIELDS = {
    "topic": "Chủ đề",
    "intent_type": "Kiểu nhận diện: action/object/other",
    "english_term": "Từ tiếng Anh chính",
    "phonetic": "Phiên âm",
    "vietnamese_meaning": "Nghĩa tiếng Việt",
    "example_sentence": "Câu ví dụ",
    "response": "Câu trả lời thân thiện cho người học",
}

GENERALIZATION_RULES: Dict[str, str] = {
    r"\b(dell|hp|lenovo|acer|asus|macbook)\b": "laptop",
    r"\b(iphone|samsung|oppo|xiaomi|vivo|pixel)\b": "smartphone",
    r"\b(nike|adidas|puma|reebok|new balance)\b": "shoes",
    r"\b(canon|nikon|sony|fujifilm)\b": "camera",
    r"\b(bmw|mercedes|audi|toyota|honda)\b": "car",
}

VISION_PROMPT = """
Bạn là trợ lý học từ vựng tiếng Anh. Nhận diện đối tượng chính trong ảnh và trả về DUY NHẤT một JSON hợp lệ gồm đúng các trường sau:
{
  "topic": string,
  "word": string,
  "phonetic": string,
  "vietnamese_meaning": string,
  "example_sentence": string,
  "pronunciation_guide": string,
  "word_type": string
}
Quy tắc quan trọng:
- "word" phải là tên loại/nhóm chung (ví dụ: laptop, smartphone, cat, fruit...). KHÔNG trả về tên thương hiệu, nhãn sản phẩm.
- "topic" BẮT BUỘC phải là một trong 9 từ khóa tiếng Anh sau (chọn cái phù hợp nhất): Electronics, Furniture, Animals, Nature, Technology, Learning, Food, Vehicles, Household Items.
- Không thêm bất kỳ ký tự hay chú thích nào ngoài JSON hợp lệ.
""".strip()

CHAT_PROMPT = """
Bạn là gia sư tiếng Anh cho người Việt.
Nhiệm vụ của bạn là trò chuyện, thấu hiểu ngữ cảnh và phản hồi tự nhiên với người dùng trước khi cung cấp các từ vựng tiếng Anh liên quan.
Chỉ hỗ trợ từ vựng thuộc 9 chủ đề sau: Đồ điện tử (Electronics), Đồ nội thất (Furniture), Động vật (Animals), Thiên nhiên (Nature), Công nghệ (Technology), Học tập (Learning), Đồ ăn (Food), Phương tiện (Vehicles), Đồ gia dụng (Household Items). Nếu người dùng hỏi từ vựng nằm ngoài các chủ đề này, hãy từ chối khéo léo và hướng họ về các chủ đề được hỗ trợ.
Người dùng có thể hỏi đời thường (chào hỏi, tâm sự, hỏi thông tin) hoặc mô tả hành động/đồ vật để học từ vựng.
Hãy trả về DUY NHẤT một JSON hợp lệ với đúng các trường:
{
    "topic": string,
    "intent_type": "action" | "object" | "other",
    "english_term": string,
    "phonetic": string,
    "vietnamese_meaning": string,
    "example_sentence": string,
    "response": string
}
Yêu cầu:
- Nếu là hội thoại đời thường, trả lời tự nhiên bằng tiếng Việt, intent_type="other".
- Với hội thoại đời thường hoặc ngoài chủ đề: english_term="", phonetic="", vietnamese_meaning="", example_sentence="".
- Nếu người dùng đang mô tả hành động, intent_type phải là "action".
- Nếu người dùng đang mô tả đồ vật, intent_type phải là "object".
- Nếu người dùng hỏi chủ đề ngoài danh sách cho phép, intent_type="other" và giải thích khéo léo trong "response", yêu cầu họ chọn chủ đề hợp lệ.
- Nếu không rõ, đặt "other" và vẫn hướng dẫn thân thiện.
- Nếu là action/object thuộc chủ đề hợp lệ, trong "response" hãy trò chuyện, thấu hiểu ngữ cảnh và dẫn dắt người dùng trước rồi mới nêu: "Từ tiếng Anh là ...".
- Không đưa ký hiệu IPA trực tiếp vào "response" để phù hợp bộ đọc giọng nói; IPA chỉ để trong trường "phonetic".
- "topic" BẮT BUỘC TRẢ VỀ TỪ KHÓA TIẾNG ANH CHUẨN từ: Electronics, Furniture, Animals, Nature, Technology, Learning, Food, Vehicles, Household Items. Nếu là hội thoại "other" ngoài danh sách thì trả về "".
- Không thêm bất kỳ ký tự hay chú thích nào ngoài JSON hợp lệ.
""".strip()


class ChatMessage(BaseModel):
    role: str = Field(..., description="user hoac assistant")
    content: str


class ChatRequest(BaseModel):
    message: str
    history: List[ChatMessage] = Field(default_factory=list)


class ChatResponseData(BaseModel):
    topic: str
    intent_type: str
    english_term: str
    phonetic: str
    vietnamese_meaning: str
    example_sentence: str
    response: str



def get_groq_client() -> Groq:
    api_key = os.getenv("GROQ_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="Chưa cấu hình GROQ_API_KEY trong môi trường.",
        )
    return Groq(api_key=api_key)



def encode_image(image_bytes: bytes) -> str:
    return base64.b64encode(image_bytes).decode("utf-8")



def preprocess_image(image_bytes: bytes) -> str:
    try:
        img = Image.open(BytesIO(image_bytes))
        img = img.convert("RGB")
        img.thumbnail((640, 640), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=85)
        return encode_image(buffer.getvalue())
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Ảnh không hợp lệ: {exc}")



def build_vision_messages(base64_image: str) -> List[Dict[str, Any]]:
    return [
        {"role": "system", "content": VISION_PROMPT},
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "Phân tích ảnh và trả kết quả đúng format JSON đã mô tả.",
                },
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"},
                },
            ],
        },
    ]



def build_chat_messages(request: ChatRequest) -> List[Dict[str, str]]:
    messages: List[Dict[str, str]] = [{"role": "system", "content": CHAT_PROMPT}]

    # Lấy 6 tin nhắn gần nhất
    history_slice = request.history[-6:]
    
    # Llama/Groq yêu cầu nghiêm ngặt: tin nhắn đầu tiên sau 'system' KHÔNG được là 'assistant'
    while history_slice and history_slice[0].role != "user":
        history_slice.pop(0)

    for item in history_slice:
        role = "assistant" if item.role == "assistant" else "user"
        # Bỏ qua nếu 2 tin nhắn liên tiếp trùng role (Llama sẽ báo lỗi 400 Bad Request nếu không luân phiên)
        if len(messages) > 1 and messages[-1]["role"] == role:
            messages[-1]["content"] += f"\n{item.content}"
        else:
            messages.append({"role": role, "content": item.content})

    # Thêm tin nhắn hiện tại của người dùng (tránh trùng role user ở cuối)
    if len(messages) > 1 and messages[-1]["role"] == "user":
        messages[-1]["content"] += f"\n{request.message}"
    else:
        messages.append({"role": "user", "content": request.message})
        
    return messages



def generalize_word(word: str) -> str:
    normalized = word.strip().lower()
    for pattern, generic in GENERALIZATION_RULES.items():
        if re.search(pattern, normalized):
            return generic
    return word



def _extract_json(raw_content: str) -> Dict[str, Any]:
    content = raw_content.strip()
    match = re.search(r"\{.*\}", content, re.DOTALL)
    if match:
        content = match.group(0)
    return json.loads(content)



def validate_analysis(payload: Dict[str, Any]) -> Dict[str, Any]:
    # Nếu AI thiếu trả về khóa, tự động gán rỗng để tránh lỗi 502
    for field in REQUIRED_FIELDS:
        if field not in payload:
            payload[field] = ""

    payload["word"] = generalize_word(str(payload["word"]))
    return payload



def validate_chat_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    # Nếu AI thiếu trả về khóa, tự động gán rỗng để tránh lỗi 502
    for field in CHAT_REQUIRED_FIELDS:
        if field not in payload:
            payload[field] = ""

    intent = str(payload.get("intent_type", "other")).strip().lower()
    if intent not in {"action", "object", "other"}:
        payload["intent_type"] = "other"
    else:
        payload["intent_type"] = intent

    payload["english_term"] = str(payload.get("english_term", "")).strip()
    payload["phonetic"] = str(payload.get("phonetic", "")).strip()
    payload["vietnamese_meaning"] = str(payload.get("vietnamese_meaning", "")).strip()
    payload["example_sentence"] = str(payload.get("example_sentence", "")).strip()
    payload["response"] = str(payload.get("response", "")).strip()
    payload["topic"] = str(payload["topic"]).strip() or "General"

    if not payload["response"]:
        raise HTTPException(status_code=502, detail="Groq thiếu nội dung response")

    return payload


async def call_groq_vision(base64_image: str) -> Dict[str, Any]:
    client = get_groq_client()

    def _request() -> Dict[str, Any]:
        completion = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=build_vision_messages(base64_image),
            temperature=0.35,
            max_tokens=512,
            top_p=1,
            stream=False,
        )

        raw_content = completion.choices[0].message.content or "{}"
        payload = _extract_json(raw_content)
        return validate_analysis(payload)

    try:
        return await run_in_threadpool(_request)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=502, detail=f"Groq trả về JSON không hợp lệ: {exc}")
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Lỗi gọi Groq Vision API: {exc}")
        raise HTTPException(status_code=502, detail=f"Groq lỗi: {exc}")


async def call_groq_chat(request: ChatRequest) -> Dict[str, Any]:
    client = get_groq_client()

    def _request() -> Dict[str, Any]:
        completion = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=build_chat_messages(request),
            temperature=0.45,
            max_tokens=420,
            top_p=1,
            stream=False,
        )

        raw_content = completion.choices[0].message.content or "{}"
        payload = _extract_json(raw_content)
        return validate_chat_payload(payload)

    try:
        return await run_in_threadpool(_request)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=502, detail=f"Groq trả về JSON chat không hợp lệ: {exc}")
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Lỗi gọi Groq Chat API: {exc}")
        raise HTTPException(status_code=502, detail=f"Groq chat lỗi: {exc}")


async def process_image_upload(file: UploadFile) -> Dict[str, Any]:
    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="File ảnh rỗng.")

    base64_image = preprocess_image(contents)
    analysis = await call_groq_vision(base64_image)
    return {
        "status": "success",
        "data": analysis,
        "message": "Image analysis completed successfully",
    }


@health_router.get("")
async def health_check():
    return {"status": "ok"}


@vision_router.post("/analyze-image")
async def analyze_image(file: UploadFile = File(...)):
    return await process_image_upload(file)


@app.post("/analyze-image", include_in_schema=False)
async def analyze_image_legacy(file: UploadFile = File(...)):
    return await process_image_upload(file)


@chat_router.post("/respond")
async def chat_respond(request: ChatRequest):
    if not request.message.strip():
        raise HTTPException(status_code=400, detail="Message rong")

    data = await call_groq_chat(request)
    return {
        "status": "success",
        "data": ChatResponseData(**data).model_dump(),
        "message": "Chat completed successfully",
    }


@app.post("/chat", include_in_schema=False)
async def chat_legacy(request: ChatRequest):
    data = await call_groq_chat(request)
    return {"status": "success", "data": data, "message": "Chat completed successfully"}


app.include_router(health_router)
app.include_router(vision_router)
app.include_router(chat_router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
