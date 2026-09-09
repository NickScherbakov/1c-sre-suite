# Редакционный стиль цикла «1C:SRE-Suite» (Infostart.ru)

Единый визуальный и текстовый стандарт для всех статей серии и её будущих
сиквелов («Чёрный пояс 1С», «Предельные режимы», «Викторина для (сурового)
админа», «Практикум» и т.д.). Цель — чтобы читатель узнавал материалы цикла
с первого экрана, независимо от того, кто именно писал конкретную статью.

Все HTML-фрагменты рассчитаны на вставку в редактор Infostart.ru как есть
(инлайн-стили, без внешних CSS/JS — площадка их не сохраняет).

## 1. Шапка статьи — «визитка»

Первый блок каждой статьи. Синяя плашка с заголовком, подзаголовком-тизером
и мета-информацией о проекте.

```html
<div style="background: #f4f8fc; border-left: 5px solid #0066cc; border-radius: 6px; padding: 18px 22px; margin-bottom: 25px; box-shadow: 0 1px 3px rgba(0,0,0,0.03);">
<div style="font-size: 22px; font-weight: bold; color: #0066cc; line-height: 1.35; margin-bottom: 8px;">Заголовок статьи</div>

<div style="font-size: 15px; color: #2c3e50; line-height: 1.5; margin-bottom: 12px;">Тизер-подзаголовок в 1-2 предложения.</div>

<div style="font-size: 13.5px; color: #4b5563; line-height: 1.6; border-top: 1px solid #e2e8f0; padding-top: 10px;">
<div><strong>Серия публикаций:</strong> <a href="..." style="color: #0066cc; text-decoration: none;" target="_blank">Название цикла</a></div>
<div><strong>Авторы проекта:</strong> Нинель и&nbsp;Николай Щербаковы</div>
<div><strong>Репозиторий проекта:</strong> <a href="https://github.com/NickScherbakov/1c-sre-suite" style="color: #0066cc; text-decoration: none; font-weight: bold;" target="_blank">NickScherbakov/1c-sre-suite</a></div>
</div>
</div>
```

## 2. Оглавление

Белая карточка сразу под шапкой, нумерованный список с якорями на `#section-N`.

```html
<div style="border: 1px solid #dbe2ea; border-radius: 8px; padding: 18px 22px; background-color: #ffffff; margin-bottom: 30px; box-shadow: 0 1px 2px rgba(0,0,0,0.04);">
<div style="font-weight: bold; font-size: 16px; margin-bottom: 10px; color: #111827;">Оглавление:</div>
<ol style="margin: 0; padding-left: 22px; line-height: 1.85; font-size: 14.5px;">
	<li><a href="#section-1" style="color: #0066cc; text-decoration: none;">...</a></li>
</ol>
</div>
```

## 3. Заголовки разделов (`<h2>`)

Один эмодзи, задающий тему раздела (архитектура/решение/структура/запуск/
планы), плюс двухцветная надпись: нейтральная часть тёмная, акцентная — синяя.

```html
<h2 id="section-N" style="font-size: 19px; line-height: 1.4; margin-top: 35px; margin-bottom: 14px; border-bottom: 1px solid #e5e7eb; padding-bottom: 8px;"><span style="color: #111827; font-weight: bold;">Эмодзи + нейтральная часть:</span> <span style="color: #0066cc; font-weight: bold;">акцентная часть</span></h2>
```

Устоявшийся набор эмодзи по смыслу раздела (расширяем по мере надобности,
не смешиваем несколько эмодзи в одном заголовке):
`🎯` решение, `📂` структура/обзор, `🛠` практика/запуск, `🤝` планы/roadmap,
`⚙️` автоматизация, `🏛️` концепция, `🛡️` защита/безопасность.

## 4. Врезка «Важно» (compliance / предупреждения по существу)

Используется, когда нужно явно снять вопрос о соответствии правилам
Infostart.ru (прямой доступ к СУБД, границы применимости кода и т.п.) —
**не** путать с обязательным предупреждением площадки
(см. `warning.txt`/`warning.bmp` в отдельных статьях, где оно требуется).
Зелёная рамка — сигнал «мы разобрали риск и сняли его», а не «осторожно».

```html
<p style="background: #f7faf7; border-left: 4px solid #2e7d32; border-radius: 4px; padding: 12px 16px; font-size: 14px; color: #1b3a1e;"><strong>Важно:</strong> текст пояснения.</p>
```

## 5. Блоки кода

Тёмно-серая обвязка с заголовком-табом (язык + подпись файла) и построчной
нумерацией — используется для больших листингов; для однострочных команд
достаточно простого `<pre><code>`.

```html
<div style="background-color: #f4f6f9; border: 1px solid #dcdfe6; border-radius: 6px; margin: 16px 0; overflow: hidden; box-shadow: 0 2px 6px rgba(0,0,0,0.04);">
  <div style="background-color: #e6eaf0; color: #1e3a8a; font-size: 11pt; font-weight: 600; padding: 7px 14px; border-bottom: 1px solid #dcdfe6; display: flex; justify-content: space-between; align-items: center;">
    <span>Bash &mdash; краткая подпись + путь к файлу</span>
    <span style="color: #718096; font-weight: normal; font-size: 9pt;">Метка справа</span>
  </div>
  <div style="overflow-x: auto; padding: 12px 16px; background-color: #f4f6f9;">
    <pre style="margin: 0; font-family: Consolas, 'JetBrains Mono', monospace; font-size: 10.5pt; line-height: 1.5; color: #0a2540;">...</pre>
  </div>
</div>
```

## 6. Раздел «Предыдущие материалы цикла» (всегда последний, `#section-N` = «Предыдущие материалы»)

```html
<div id="section-N" style="margin-top: 40px; padding-top: 15px; border-top: 1px solid #e5e7eb;">
<p style="font-style: italic; color: #4b5563;">Если вы хотите подробнее ознакомиться с&nbsp;другими архитектурными решениями нашего проекта, рекомендуем прочитать наши предыдущие материалы:</p>
<ul style="line-height: 1.8; font-size: 14.5px;">
	<li><a href="..." rel="noopener noreferrer" style="color: #0066cc; text-decoration: none;" target="_blank">...</a></li>
</ul>
</div>
```

## 7. Тон и язык

- Обращение к читателю на «вы», без панибратства и без канцелярита.
- Технические термины — на языке оригинала в `<code>` (`Patroni`, `etcd`,
  `pg_anon`), русские падежные окончания через `&nbsp;` перед термином там,
  где иначе возможен перенос строки посреди связки (`с&nbsp;помощью Ansible`).
- Каждый раздел объясняет **почему**, а не только **как** — решение сначала
  мотивируется (какую проблему снимает), потом даётся механика.
- Никаких прямых SQL-обращений к таблицам информационной базы 1С и никаких
  недокументированных приёмов в рекомендуемом коде — см. `rules.txt`
  (правила модерации Infostart.ru). Если материал по природе образовательный
  и разбирает именно риски прямого доступа к СУБД — обязательно предупреждение
  площадки, см. `warning.txt`.

## 8. Единая нумерация проекта

Слаги статей в `docs/articles/` — `article-DDMMYY.html`, по дате первого
черновика (не публикации). README ссылается на каждую опубликованную статью
одной строкой с логотипом Infostart и подписью «Первая/Вторая/... часть».
