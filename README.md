# Лаборатори №6 — Category-Partition ба PICT

**Хичээл:** F.CSA313 — Программ хангамжийн чанарын баталгаа ба тест (2026)  
**Оюутны нэр:** О. Доржсамбуу  
**Оюутны код:** B232270071

Энэ лабораторийн ажлаар банкны шилжүүлгийн `POST /transfer` үйлдэлд Category-Partition аргаар тестийн нөхцөлүүдийг тодорхойлж, Microsoft PICT ашиглан хослолын тест үүсгэв. Browser моделийн 2-way болон 3-way үр дүнг харьцуулж, шилжүүлгийн гурван моделийн ялгааг судалсан. PICT-ийн үр дүнг Windows 11 дээр өөрөө үүсгэсэн бөгөөд API-ийн хүлээгдэх хариуг өгөгдсөн дүрэм, тестийн орчны нөхцөлд үндэслэн тодорхойлов.

## Ашигласан орчин ба PICT тохиргоо

- Үйлдлийн систем: Windows 11, PowerShell
- CMake: 4.4.4; Ninja: 1.13.2; MSYS2 GCC: 15.2.0
- PICT: 3.7.4, Microsoft-ийн эх кодоос `pict_cli` target-ийг бүтээсэн
- MinGW `windres` нь `cli/Resource.rc` дээр алдаа өгсөн тул CLI build-ийн CMake тохиргооноос зөвхөн resource файлыг хассан. Үндсэн C++ эх код өөрчлөгдөөгүй.

```powershell
cd C:\Users\User\Documents\tools\pict
# cli/CMakeLists.txt дахь set(pict_cli_rc ...) хэсгийг set(pict_cli_rc) болгосон
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=g++ -DPICT_RUN_TESTS_ENABLED=OFF
cmake --build build --target pict_cli --config Release
.\build\cli\pict.exe /?
```

PICT-ийн эх код лабораторийн репозиторийн гадна `Documents/tools/pict` хавтсанд байна. Тестийн үр дүнг `results/`-д хадгалсан.

### Үр дүнг дахин үүсгэх (PowerShell)

```powershell
cd C:\Users\User\Documents\lab06\lab06_category_partition_pict
$pict = 'C:\Users\User\Documents\tools\pict\build\cli\pict.exe'
New-Item -ItemType Directory -Force results | Out-Null
& $pict browser.model /o:2 | Set-Content -Encoding utf8 results\browser-pairwise.txt
& $pict browser.model /o:3 | Set-Content -Encoding utf8 results\browser-3wise.txt
& $pict transfer-nc.model | Set-Content -Encoding utf8 results\transfer-nc.txt
& $pict transfer.model | Set-Content -Encoding utf8 results\transfer.txt
& $pict transfer-neg.model | Set-Content -Encoding utf8 results\transfer-neg.txt
```

## A. Category-Partition: `POST /transfer`

```json
{"from":"A001","to":"A002","amount":100,"currency":"USD"}
```

**Дүрэм:** `from` данс байх, царцаагдаагүй байх; `to` данс байх, `from`-оос өөр байх; `amount` эерэг, хөрвүүлсний дараа үлдэгдэл ба өдрийн үлдсэн лимитээс хэтрэхгүй байх; өөр валюттай бол хөрвүүлэх. Амжилт `201 {"result":"OK"}`, алдаа `200 {"result":"ERROR_..."}`.

### Алдааны давуу эрэмбэ

`ERROR_NO_FROM → ERROR_FROZEN → ERROR_NO_TO → ERROR_SAME_ACCOUNT → ERROR_BAD_AMOUNT → ERROR_INSUFFICIENT → ERROR_LIMIT`.

**Үндэслэл:** Дансны хүчинтэй байдлыг эхэлж, дараа нь шилжүүлэх дүн ба санхүүгийн хоёр хязгаарыг шалгах нь хүлээгдэх үр дүнг давхар алдаатай хүсэлтэд тогтвортой тодорхойлох боломж олгоно. Энэ бол **тест дизайны таамаглал**, кодгүй учир батлагдсан системийн зан төлөв биш.

### A1. Fixture ба төлөөлөх утга

`A001`: идэвхтэй USD, үлдэгдэл 1000 USD, өдрийн лимит 500 USD.  
`A002`: идэвхтэй USD, тусдаа данс.  
`A003`: царцаагдсан USD данс.  
`X999`: байхгүй данс.  
Ханш: `1 USD = 3400 MNT`; `1 EUR = 1.10 USD`. `currency` нь гүйлгээний дүнгийн валют бөгөөд `from` дансны валютад хөрвүүлж шалгана. Лимитийн **үлдэгдэл** = 500 − өнөөдөр шилжүүлсэн USD. `to` данс царцаагдсан байх нь энэ тодорхойлолтоор хориглогдоогүй.

| Категори | Сонголт, төлөөлөх утга | Тэмдэглэгээ, үндэслэл |
|---|---|---|
| From | Valid (`A001`) | `[property FROM_OK]`, шалгалтыг үргэлжлүүлнэ |
| From | Frozen (`A003`) | `[ERROR]`, `ERROR_FROZEN` |
| From | Missing (`X999`) | `[ERROR]`, `ERROR_NO_FROM` |
| To | Valid (`A002`) | `[property TO_OK]`, хүчинтэй тусдаа данс |
| To | Missing (`X999`) | `[ERROR]`, `ERROR_NO_TO` |
| To | SameAsFrom (`A001`) | `[ERROR] [IF FROM_OK]`, `ERROR_SAME_ACCOUNT` |
| To | FrozenTo (`A003`) | `[SINGLE]`, from биш тул царцаалт хориглоогүй |
| Amount | Normal (`100 USD`) | `[property AMT_OK]`, эерэг, хязгаар дотор |
| Amount | Negative (`-50 USD`) | `[ERROR]`, `ERROR_BAD_AMOUNT` |
| Amount | Zero (`0 USD`) | `[ERROR]`, `ERROR_BAD_AMOUNT`-ийн хил |
| Amount | MinPositive (`0.01 USD`) | `[SINGLE]`, эерэг талын хил |
| Amount | AtLimit (`500 USD`) | `[SINGLE] [IF DailyLimit=Free]`, лимиттэй тэнцүү |
| Amount | OverLimit (`600 USD`) | `[ERROR]`, үлдэгдэл хүрэлцэх ч лимит хэтэрнэ |
| Amount | AtBalance (`1000 USD`) | `[SINGLE]`, үлдэгдэлтэй тэнцүү, **үр дүн нь ERROR_LIMIT** (`L < B`) |
| Amount | OverBalance (`1000.01 USD`) | `[ERROR]`, `ERROR_INSUFFICIENT` |
| Amount | OverLimitAfterConv (`460 EUR = 506 USD`) | `[ERROR] [IF Currency=EUR]`, хөрвүүлсний дараа лимит хэтэрнэ |
| Currency | Same (`USD`) | `[property SAME]`, хөрвүүлэлтгүй |
| Currency | MNT (`340000 MNT = 100 USD`) | `[property CONV]`, хөрвүүлэлттэй |
| Currency | EUR (`100 EUR = 110 USD`) | `[property CONV]`, хөрвүүлэлттэй |
| DailyLimit (орчин) | Free (0/500 ашигласан) | `[property FREE]`, 500 USD үлдсэн |
| DailyLimit (орчин) | Partial (300/500 ашигласан) | `[property PARTIAL]`, 200 USD үлдсэн |
| DailyLimit (орчин) | Full (500/500 ашигласан) | `[ERROR] [IF amount>0]`, `ERROR_LIMIT` |
| Balance (орчин) | Positive (`1000 USD`) | `[property BAL_POS]`, хэвийн үлдэгдэл |
| Balance (орчин) | Zero (`0 USD`) | `[ERROR] [IF amount>0]`, `ERROR_INSUFFICIENT` |

**Ангиллын тайлбар.** `[ERROR]` нь тухайн сонголтоос гарч болох алдааг зориуд тусгаарлан шалгах тэмдэг; `[SINGLE]` нь хил болон онцгой төлөвийг нэг удаа төлөөлөх зарчим; `[IF/property]` нь утгын хамаарал ба зөвшөөрөгдөх хүрээг тодорхойлно. `AtBalance`-ийг `[SINGLE]` гэж тэмдэглэсэн нь амжилт гэсэн үг биш; `1000 USD` нь 500 USD лимит давсан тул `ERROR_LIMIT`.

**Хамрах хүрээний чухал нөхцөл:** `Amount`-ийн нэрлэсэн ангиллууд нь ихэвчлэн USD данс + USD валют + Free лимит + Positive үлдэгдэл fixture дээр тодорхой утгатай. Модельд `Amount=Normal` ба `Currency=MNT` гарвал 100 биш 340000 MNT, `Currency=EUR` гарвал 100 EUR гэж бодит body болгон хувиргана. Ийм хамаарлыг зөвхөн Cartesian үржвэрээр шийдэх боломжгүй тул бодит oracle-ыг тусгайлан тогтооно.

### A2. Тестийн тоог бууруулах төлөвлөлт

Хэмжээсүүд: `From=3`, `To=4`, `Amount=9`, `Currency=3`, `DailyLimit=3`, `Balance=2`.

**Бүрэн олонлог:** `3 × 4 × 9 × 3 × 3 × 2 = 1944`.

Энэ нь параметрийн нэрлэсэн ангиллуудын **хязгаарлалтгүй бүрэн үржвэр**. `[ERROR]` болон `[SINGLE]` ашиглан нэг нэгээр нь тусгаарладаг энгийн category-partition төлөвлөгөөний доорх **зорилтот багц** нь 21 тест юм:

- Ерөнхий хүчинтэй суурь: 1.
- Суурийн валют (2 нэмэлт: MNT, EUR) ба Partial лимитийн бүх валютын 3 хувилбар: 5 нэмэлт; нийлээд 6 хэвийн.
- `From`: 2 тусгаарласан алдаа.
- `To`: 2 тусгаарласан алдаа + 1 SINGLE.
- `Amount`: Negative, Zero, OverLimit, AtBalance, OverBalance, OverLimitAfterConv = 6 тусгай алдаа/хил + MinPositive, AtLimit = 2 SINGLE. **AtBalance нэг л удаа тоологдоно.**
- `DailyLimit=Full`: 1 тусгаарласан алдаа.
- `Balance=Zero`: 1 тусгаарласан алдаа.

Ингээд `6 + 2 + 3 + 8 + 1 + 1 = 21` тест. Энэ **21 нь зориудаар сонгосон гараар төлөвлөсөн багцын хэмжээ**, PICT-ийн IF дүрмээр бүх боломжит хууль ёсны Cartesian мөрийг тоолсон үр дүн **биш**. Үүн дээр олон алдаатай туршилтуудыг нэмснээр A3 нийт 26 тест болно. Товч: **1944 → 21 (үндсэн төлөвлөгөө) → 26 (5 давхар алдаатай тест нэмсэн)**.

`SINGLE` нь тестийн багцад тухайн сонголтыг нэг удаа оруулах зорилго, харин PICT-ийн constraint дотор бүх хослолыг хасах цорын ганц утга биш. `transfer.model` зөвхөн утга учиртай хилийн хамаарлуудыг тогтоосон; `transfer-neg.model` нь `~` тэмдэглэгээгээр алдаатай сонголтуудыг ялгана. `transfer-nc.model` нь огт хязгаарлалтгүй.

### A3. Тестийн спецификаци

Бүх алдааны HTTP статус **200**, амжилтынх **201**. Тусгайлан өөрөөр заагаагүй бол from=`A001`, to=`A002`, Currency=`USD`, өдрийн хэрэглээ=0, from үлдэгдэл=1000 USD.

| # | From | To | Amount | Currency | DailyLimit | Balance | Oracle |
|---|---|---|---|---|---|---|---|
| S01 | Valid | Valid | 100 | USD | Free | Positive | `201 OK` |
| S02 | Valid | Valid | 340000 | MNT | Free | Positive | `201 OK` |
| S03 | Valid | Valid | 100 | EUR | Free | Positive | `201 OK` |
| S04 | Valid | Valid | 100 | USD | Partial | Positive | `201 OK` |
| S05 | Valid | Valid | 340000 | MNT | Partial | Positive | `201 OK` |
| S06 | Valid | Valid | 100 | EUR | Partial | Positive | `201 OK` |
| S07 | Valid | FrozenTo | 100 | USD | Free | Positive | `201 OK` |
| S08 | Valid | Valid | 0.01 | USD | Free | Positive | `201 OK` |
| S09 | Valid | Valid | 500 | USD | Free | Positive | `201 OK` |
| S10 | Missing | Valid | 100 | USD | Free | Positive | `200 ERROR_NO_FROM` |
| S11 | Frozen | Valid | 100 | USD | Free | Positive | `200 ERROR_FROZEN` |
| S12 | Valid | Missing | 100 | USD | Free | Positive | `200 ERROR_NO_TO` |
| S13 | Valid | SameAsFrom | 100 | USD | Free | Positive | `200 ERROR_SAME_ACCOUNT` |
| S14 | Valid | Valid | -50 | USD | Free | Positive | `200 ERROR_BAD_AMOUNT` |
| S15 | Valid | Valid | 0 | USD | Free | Positive | `200 ERROR_BAD_AMOUNT` |
| S16 | Valid | Valid | 600 | USD | Free | Positive | `200 ERROR_LIMIT` |
| S17 | Valid | Valid | 1000 | USD | Free | Positive | `200 ERROR_LIMIT` |
| S18 | Valid | Valid | 1000.01 | USD | Free | Positive | `200 ERROR_INSUFFICIENT` |
| S19 | Valid | Valid | 460 | EUR | Free | Positive | `200 ERROR_LIMIT` |
| S20 | Valid | Valid | 100 | USD | Full | Positive | `200 ERROR_LIMIT` |
| S21 | Valid | Valid | 100 | USD | Free | Zero | `200 ERROR_INSUFFICIENT` |
| S22 | Frozen | SameAsFrom | 100 | USD | Free | Positive | `200 ERROR_FROZEN` |
| S23 | Valid | Missing | -50 | USD | Free | Positive | `200 ERROR_NO_TO` |
| S24 | Valid | Valid | 0 | USD | Free | Zero | `200 ERROR_BAD_AMOUNT` |
| S25 | Valid | Valid | 1000.01 | USD | Full | Positive | `200 ERROR_INSUFFICIENT` |
| S26 | Valid | Valid | 910 | EUR | Free | Positive | `200 ERROR_INSUFFICIENT` |

**S22–S26** нь error masking болон тогтоосон давуу эрэмбийг шалгана. S26-д `910 EUR × 1.10 = 1001 USD` тул үлдэгдэл болон лимит хоёулаа хэтэрсэн ч `ERROR_INSUFFICIENT` түрүүлж сонгогдоно.

## B. PICT ашигласан хослолын тест

### B1. Browser

`browser.model` нь лекцийн зургаан хэмжээсийг агуулна. Бүрэн олонлог `3 × 3 × 2 × 2 × 2 × 2 = 144`.

Windows дээр PICT 3.7.4 ашиглан үүсгэсэн бодит үр дүн:

| Түвшин | Үүссэн тест | Бүрэн олонлог |
|---|---:|---:|
| 2-way | 10 | 144 |
| 3-way | 20 | 144 |

2-way-ийн онолын доод хязгаар дор хаяж `3×3=9`, харин 3-way-д дор хаяж `3×3×2=18` мөр хэрэгтэй. PICT нь greedy алгоритм тул практикт эдгээр доод хязгаараас их тест үүсгэж болно; хамгийн цөөн тестийг заавал олох баталгаа байхгүй. 3-way нь гурван параметрийн бүх боломжит хослолыг хамруулах учраас 2-way-гээс олон мөр шаардаж болно.

### B2. Шилжүүлгийн гурван модель

- `transfer-nc.model`: хязгаарлалтгүй 6 хэмжээс (1944 нэрлэсэн хослол).
- `transfer.model`: утга учиртай хил болон хамаарлыг `IF`-ээр хязгаарлаж, зориуд давхар алдааг **бүрмөсөн хориглоогүй**.
- `transfer-neg.model`: алдаатай сонголтуудад `~` тэмдэглэгээ ашиглан negative тестүүдийг тусад нь үүсгэнэ. `FrozenTo`, `MinPositive`, `AtLimit` нь сөрөг биш.

**Анхаар:** `~` хэрэглэсэн ч `SameAsFrom`-ын утгаас `From=Missing` зэрэг харилцан хамаарал, хөрвүүлэлтийн нөхцөлийг `IF`-ээр илэрхийлэх шаардлагатай. Мөн `Normal` болон `AtLimit` зэрэг ангиллыг валют, үлдэгдэл, ашигласан өдрийн лимиттэй нийцүүлэн бодит утга болгон хувиргах ёстой.

| Модель | Үүссэн тест | Тайлбар |
|---|---:|---|
| `transfer-nc.model` | 36 | IF хязгаарлалтгүй pairwise |
| `transfer.model` | 36 | IF хязгаарлалттай pairwise |
| `transfer-neg.model` | 48 | `~` negative сонголтуудтай pairwise |

`transfer-nc` болон `transfer` ижил 36 мөр гарсан нь хязгаарлалт ажиллаагүй гэсэн баталгаа биш. Хязгаарлалтыг хангаж байгаа эсэхийг мөр тус бүрээр шалгах ёстой. `transfer-neg`-ийн 48 мөр нь алдааны сонголтуудыг илүү тусгаарлан төлөөлсөн үр дүн байж болох ч бодит хамралтыг тооцоолохгүйгээр сайн/муу гэж дүгнэхгүй.

#### PICT-ийн гаралтаас сонгосон тест тохиолдлууд

`results/transfer-neg.txt` файлаас дараах дөрвөн мөрийг сонгож, банкны шилжүүлгийн хүсэлт болон хүлээгдэх хариутай холбов. Мөрийн дугаарт баганын гарчгийг оруулаагүй. `~` тэмдэг нь PICT-ийн negative сонголтын тэмдэглэгээ бөгөөд API-д илгээх утгад орохгүй.

| Тест | PICT мөр | From | To | Amount | Currency | DailyLimit | Balance | Хүлээгдэх хариу |
|---|---:|---|---|---|---|---|---|---|---|
| TC01 | 5 | Valid | Valid | Normal | Same | Free | Positive | `201 OK` |
| TC02 | 10 | Valid | ~SameAsFrom | AtLimit | Same | Free | Positive | `200 ERROR_SAME_ACCOUNT` |
| TC03 | 11 | ~Missing | FrozenTo | AtLimit | Same | Free | Positive | `200 ERROR_NO_FROM` |
| TC04 | 12 | Valid | FrozenTo | ~AtBalance | Same | Free | Positive | `200 ERROR_LIMIT` |

**TC01 — Амжилттай шилжүүлэг (5-р мөр).** Илгээгч `A001`, хүлээн авагч `A002`; үлдэгдэл 1000 USD, өдрийн ашигласан лимит 0 USD. Хүсэлтийн body: `{"from":"A001","to":"A002","amount":100,"currency":"USD"}`. Хүлээгдэх хариу: HTTP `201`, `{"result":"OK"}`. Шилжүүлэг хийгдвэл илгээгчийн үлдэгдэл 900 USD болно.

**TC02 — Өөрийн данс руу шилжүүлэх (10-р мөр).** `SameAsFrom` нөхцөлийн дагуу илгээгч болон хүлээн авагчийг `A001` гэж авна. Хүсэлтийн body: `{"from":"A001","to":"A001","amount":500,"currency":"USD"}`. Хүлээгдэх хариу: HTTP `200`, `{"result":"ERROR_SAME_ACCOUNT"}`. Дүн нь лимиттэй тэнцүү боловч ижил дансны шалгалт түрүүлж хийгдэнэ.

**TC03 — Илгээгчийн данс байхгүй (11-р мөр).** Илгээгч `X999`, хүлээн авагч `A003`; үлдэгдлийн орчин нь Positive, өдрийн лимит Free гэж тэмдэглэгдсэн. Хүсэлтийн body: `{"from":"X999","to":"A003","amount":500,"currency":"USD"}`. Хүлээгдэх хариу: HTTP `200`, `{"result":"ERROR_NO_FROM"}`. Илгээгчийн данс байхгүй тул шилжүүлэг хийгдэхгүй.

**TC04 — Өдрийн лимит хэтрэх (12-р мөр).** Илгээгч `A001`, хүлээн авагч `A003`; үлдэгдэл 1000 USD, өдрийн лимит 500 USD. Хүсэлтийн body: `{"from":"A001","to":"A003","amount":1000,"currency":"USD"}`. Хүлээгдэх хариу: HTTP `200`, `{"result":"ERROR_LIMIT"}`. Дүн нь үлдэгдэлтэй тэнцүү боловч өдрийн лимитээс давсан. Энэ даалгаврын тодорхойлолтод хүлээн авагчийн данс царцаагдсан байхыг хориглоогүй.

Эдгээр нь PICT-ээр үүссэн бодит мөрүүдэд тулгуурласан **тестийн спецификаци** юм. Банкны API-г ажиллуулж, HTTP хариуг бодитоор хэмжсэн тестийн тайлан биш.

### B3. Харьцуулалт

| Шалгуур | Гараар Category-Partition | PICT |
|---|---|---|
| Алдааны шалтгаан ба oracle | Давуу талтай | Гараар нөхөх шаардлагатай |
| 2-way/3-way хамралт | Гараар баталгаажуулна | Автоматаар үүсгэнэ |
| Хил ба тусгай утга | Нарийн хянахад сайн | Хязгаарлалт/загвар шаарддаг |
| Давхар алдаа | Зориудаар сонгоход сайн | `~` эсвэл IF байхгүй бол error masking |
| Өргөтгөл | Гар ажиллагаа өснө | Модель шинэчлээд дахин үүсгэнэ |

## Дүгнэлт

Энэ лабораторид Category-Partition ба PICT ашиглан банкны шилжүүлгийн тестийг код бичихээс өмнө загварчиллаа. Category-Partition аргаар параметр бүрийн хэвийн, алдаатай болон хилийн утгуудыг тусгаарлав. Бүрэн олонлог 1944 боломжит хослолтой байгааг тодорхойлж, 21 үндсэн төлөөлөх тест төлөвлөв. Үүн дээр таван давхар нөхцөлийн тест нэмснээр гараар боловсруулсан хүснэгт 26 мөр болов. Тестийн хүлээгдэх үр дүн нь алдааны давуу эрэмбээс хамаарахыг анзаарлаа. PICT нь нэрлэсэн сонголтуудын хосын хамралтыг автоматаар бүтээхэд тустай. Харин PICT өөрөө HTTP статус болон `result` кодыг тодорхойлохгүй тул oracle-ыг гараар боловсруулах шаардлагатай. Алдааны утгуудад `~` тавих нь давхар алдааны masking-ийг багасгадаг боловч бодит бизнесийн хамаарлыг илэрхийлэх IF дүрмийг орлож чадахгүй. Хамгийн их бодол шаардсан хэсэг нь валют хөрвүүлсний дараах дүнг өдрийн үлдсэн лимит, дансны үлдэгдэлтэй зөв харьцуулах байв. Иймээс Category-Partition-ийн семантик шинжилгээ болон PICT-ийн хамралтыг хослуулах нь оновчтой гэж дүгнэлээ.

## Репозиторийн бүтэц ба үр дүнгийн файлууд

Моделуудыг `browser.model`, `transfer-nc.model`, `transfer.model`, `transfer-neg.model` файлуудад хадгалсан. Үүсгэсэн тестийн мөрүүд `results/browser-pairwise.txt`, `results/browser-3wise.txt`, `results/transfer-nc.txt`, `results/transfer.txt`, `results/transfer-neg.txt` файлуудад байна. PICT-ийн бүтээсэн орчны тэмдэглэлийг `results/pict-build.txt` файлд тусад нь хадгалсан.

PICT-ийн гаралт нь параметрийн ангиллын хослолыг илэрхийлдэг тул бодит API хүсэлт болгох үед валют, дүн, дансны төлөв болон өдрийн ашигласан лимитийг тухайн тестийн нөхцөлтэй нийцүүлэн тохируулна.
