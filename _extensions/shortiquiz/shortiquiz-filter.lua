local function writeEnvironments()
    if quarto.doc.is_format("html:js") then
        quarto.doc.add_html_dependency({
            name = "alpine",
            version = "3.12",
            scripts = {
                { path = "sort-alpine.min.js", afterBody = "true" },
                { path = "alpine.min.js",      afterBody = "true" }
            },
        })
        quarto.doc.add_html_dependency({
            name = "qstyles",
            version = "1",
            stylesheets = { "qstyles.css" }
        })
    end
end

local function ShuffleInPlace(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- считаем количество пробелов в начале строки
function count_leading_spaces(str)
    local match = str:match("^%s+")
    if match then
        return #match
    else
        return 0
    end
end

function RandomStringID(length)
    local res = ""
    for i = 1, length do
        res = res .. string.char(math.random(97, 122))
    end
    return res
end

function createQinput(div)
    writeEnvironments()              -- убеждаемся, что скрипты и стили добавлены в окружение

    local question = {}              -- разметка всего вопроса

    local questionContent = {}       -- содержимое вопроса
    local hint = nil                 -- подсказка
    local stems = nil                -- варианты ответа
    local qName = RandomStringID(10) -- уникальное имя для радиокнопок для каждого вопроса

    local gateName = ""

    -- имя гейта
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    -- quarto.log.output(div)
    for _, el in ipairs(div.content) do
        if el.t == "BlockQuote" then
            hint = el.content
        elseif el.t == "OrderedList" or el.t == "BulletList" then
            stems = el
        else
            table.insert(questionContent, el)
        end
    end

    -- пропускаем рендеринг вопроса, если нет формулировки вопроса, списка ответов или в нём только 1 вариант
    if #questionContent == 0 or stems == nil or #stems.content < 1 then return pandoc.Div('') end

    local stemHints = {} -- подсказки для вариантов ответа
    local correctAnswer = nil
    for i, item in ipairs(stems.content) do
        local qHint = nil
        local answer = nil

        -- ищем в вопросе параграфы и блок-цитату
        for _, block in ipairs(item) do
            if block.t == "Para" or block.t == "Plain" then
                answer = block.content[1].text
            elseif block.t == "BlockQuote" then
                qHint = block -- содержимое цитаты станет подсказкой к ответу
            end
        end

        if i == 1 then
            correctAnswer = answer
        end

        local hintStyle = "qmulti__wrong_result"
        if i == 1 then
            hintStyle = "qmulti__correct_result"
        end

        if qHint ~= nil then
            table.insert(stemHints,
                pandoc.RawBlock("html", [[
                <div style="margin-top: 0.25em" class="]] .. hintStyle .. [[" x-show="answer === ']] .. (answer) ..
                    [[' && isAnswered" x-transition>
                ]]))
            table.insert(stemHints, pandoc.Div(qHint.content))
            table.insert(stemHints, pandoc.RawBlock("html", [[</div>]]))
        end
        -- quarto.log.output(hint)
    end

    -- открывающий div; есть отдельный стиль, если ответили с первой попытки
    table.insert(question,
        pandoc.RawBlock("html",
            [[<div class="qmulti" :class="isAnswerCorrect && attempt === 1 && 'qmulti_first_try'"
            x-data="{
                answer: '',
                correctAnswer: ']] .. correctAnswer .. [[',
                isAnswered: false,
                attempt: 0,
                isAnswerCorrect: false,
                isHintVisible: false,
                isShakeHead: false,
                checkAnswer(){
                    this.isAnswered = this.answer.length !== 0;
                    this.isAnswerCorrect = this.answer === this.correctAnswer;
                    this.attempt = this.isAnswered ? this.attempt + 1: this.attempt;
                },
                shake(){
                    this.isShakeHead = true;
                    setTimeout(() => {
                        this.isShakeHead = false;
                    }, 600);
                }
            }"
            data-gate=']] .. gateName .. [['
            x-init="$watch('isAnswerCorrect', value => {
                if (value) {
                    isCurrentAnswerCorrect = true;
                    $dispatch('answer-notification', {
                        isCorrect: true,
                        type: 'qinput',
                        gate: ']] .. gateName .. [[',
                        attempt: attempt
                    });
                }
            })"
        >]]))

    if hint ~= nil then
        buttonsHtml =
        [[<button class="qmulti__hint_button"
        type="button"
        x-show="!isHintVisible && attempt >= 1 && !isAnswerCorrect" x-transition
        x-on:click="isHintVisible=!isHintVisible">
        ?
        </button>]]
        table.insert(question,
            pandoc.RawBlock("html", buttonsHtml))
    end

    table.insert(question, pandoc.RawBlock("html", [[<div
        x-show="isAnswerCorrect"
        x-transition
        x-cloak class="qmulti__result__badge qmulti__result__correct">
    <span>✔</span></div>]]))

    table.insert(question, pandoc.RawBlock("html", [[<div
        x-show="!isAnswerCorrect && isAnswered"
        x-transition
        x-cloak class="qmulti__result__badge qmulti__result__wrong">
    <span :class="{ 'shake-head': isShakeHead }">⛌</span></div>]]))

    table.insert(question, pandoc.Div(questionContent, { class = "qmulti__question" }))
    table.insert(question, pandoc.RawBlock("html", [[<hr class="hr-text" data-content="?">]]))

    if hint ~= nil then
        table.insert(question, pandoc.RawBlock("html", [[<div x-show="isHintVisible" x-transition>]]))
        table.insert(question, pandoc.Div(hint))
        table.insert(question, pandoc.RawBlock("html", [[</div>]]))
    end

    table.insert(question, pandoc.RawBlock("html", [[
    <div class="qinput__input_container"
    x-data
        x-init="$watch('answer', value => {
            if (!isAnswerCorrect) shake();
        })"
    >
        <input
            :class="{
                'wrong': isAnswered && !isAnswerCorrect,
                'correct': isAnswerCorrect
            }"
            type="text"
            x-model.lazy="answer"
            placeholder="Введите ответ"
            x-on:change="checkAnswer"
            :disabled="isAnswerCorrect"
        />
    </div>

    <div>
        <button
            class="button__evaluate"
            x-show="!isAnswerCorrect"
            x-transition
            x-on:click="checkAnswer"
        >✓ Проверить</button>
    </div>
    ]]))

    table.insert(question, pandoc.Div(stemHints))

    table.insert(question, pandoc.RawBlock("html", [[</div>]])) -- закрывающий div

    return pandoc.Div(question, { class = "qinput__formated" })
end

-- TODO опциональный параметр - является ли вопрос частью группы
-- по умолчанию - нет (не добавлять изменение переменной isCurrentAnswerCorrect = true;)

function createQmutli(div)
    writeEnvironments()              -- убеждаемся, что скрипты и стили добавлены в окружение

    local question = {}              -- разметка всего вопроса

    local questionContent = {}       -- содержимое вопроса
    local hint = nil                 -- подсказка
    local stems = nil                -- варианты ответа
    local qName = RandomStringID(10) -- уникальное имя для радиокнопок для каждого вопроса

    local gateName = ""

    -- имя гейта
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    -- quarto.log.output(div)
    for _, el in ipairs(div.content) do
        if el.t == "BlockQuote" then
            hint = el.content
        elseif el.t == "OrderedList" or el.t == "BulletList" then
            stems = el
        else
            table.insert(questionContent, el)
        end
    end

    -- пропускаем рендеринг вопроса, если нет формулировки вопроса, списка ответов или в нём только 1 вариант
    if #questionContent == 0 or stems == nil or #stems.content < 2 then return pandoc.Div('') end

    local stemHints = {}       -- подсказки для вариантов ответа
    local questionOptions = {} -- список всех ответов
    for i, item in ipairs(stems.content) do
        local fullStem = {}    -- вариант ответа со всей разметко Alpinejs
        local option = {}
        local qHint = nil
        local qId = RandomStringID(10) -- id для label

        -- ищем в вопросе параграфы и блок-цитату
        for _, block in ipairs(item) do
            if block.t == "Para" or block.t == "CodeBlock" or block.t == "Image" or block.t == "Plain" then
                table.insert(option, block) -- параграфы сохраняем в список
            elseif block.t == "BlockQuote" then
                qHint = block               -- содержимое цитаты станет подсказкой к ответу
            end
        end

        -- первый вариант ответа всегда считается правильным и для него
        local classRule = [[answer === ']] .. (i - 1) .. [[' && isAnswered && 'qmulti__wrong']]
        local correctAnswerAction = ""
        local hintStyle = "qmulti__wrong_result"
        if i == 1 then
            classRule = "isAnswerCorrect && 'qmulti__correct'"
            correctAnswerAction = "isAnswerCorrect=true"
            hintStyle = "qmulti__correct_result"
        end
        table.insert(fullStem,
            pandoc.RawBlock("html",
                [[<div class="qmulti__stem" :class="]] .. classRule .. [[">
        <label for="]] .. qId .. [[" >]]))
        table.insert(fullStem, pandoc.Div(option))
        table.insert(fullStem, pandoc.RawBlock("html", [[</label>
    <input
            type="radio"
            class="form-check-input"
            id="]] .. qId .. [["
            value="]] .. (i - 1) .. [["
            x-model="answer"
            :disabled="isAnswerCorrect"
            name="]] .. qName .. [["
            x-on:click="attempt++; isAnswered = true; isAnswerCorrect = answer === '0';]] ..
            correctAnswerAction .. [["
        />
    </div>]]))

        if qHint ~= nil then
            table.insert(stemHints,
                pandoc.RawBlock("html", [[<div class="]] .. hintStyle .. [[" x-show="answer === ']] .. (i - 1) ..
                    [[' && isAnswered" x-transition>]]))
            table.insert(stemHints, pandoc.Div(qHint.content))
            table.insert(stemHints, pandoc.RawBlock("html", [[</div>]]))
        end

        table.insert(questionOptions, pandoc.Div(fullStem))
        -- quarto.log.output(hint)
    end

    ShuffleInPlace(questionOptions)

    -- открывающий div; есть отдельный стиль, если ответили с первой попытки
    table.insert(question,
        pandoc.RawBlock("html",
            [[<div class="qmulti" :class="isAnswerCorrect && attempt === 1 && 'qmulti_first_try'"
            x-data="{
                answer: '',
                isAnswered: false,
                attempt: 0,
                isAnswerCorrect: false,
                isHintVisible: false
            }"
            data-gate=']] .. gateName .. [['
            x-init="$watch('isAnswerCorrect', value => {
                if (value) {
                    isCurrentAnswerCorrect = true;
                    $dispatch('answer-notification', {
                        isCorrect: true,
                        type: 'qmulti',
                        gate: ']] .. gateName .. [[',
                        attempt: attempt
                    });
                }
            })"
        >]]))

    if hint ~= nil then
        buttonsHtml =
        [[<button class="qmulti__hint_button"
        type="button"
        x-show="!isHintVisible && attempt >= 1 && !isAnswerCorrect" x-transition
        x-on:click="isHintVisible=!isHintVisible">
        ?
        </button>]]
        table.insert(question,
            pandoc.RawBlock("html", buttonsHtml))
    end

    table.insert(question, pandoc.RawBlock("html", [[<div
        x-show="isAnswerCorrect"
        x-transition
        x-cloak class="qmulti__result__badge qmulti__result__correct">
    <span>✔</span></div>]]))

    table.insert(question, pandoc.Div(questionContent, { class = "qmulti__question" }))
    table.insert(question, pandoc.RawBlock("html", [[<hr class="hr-text" data-content="?">]]))

    if hint ~= nil then
        table.insert(question, pandoc.RawBlock("html", [[<div x-show="isHintVisible" x-transition>]]))
        table.insert(question, pandoc.Div(hint))
        table.insert(question, pandoc.RawBlock("html", [[</div>]]))
    end

    table.insert(question, pandoc.Div(questionOptions))

    table.insert(question, pandoc.Div(stemHints))

    table.insert(question, pandoc.RawBlock("html", [[</div>]])) -- закрывающий div

    return pandoc.Div(question, { class = "qmulti__formated" })
end

function createQcheck(div)
    writeEnvironments()        -- убеждаемся, что скрипты и стили добавлены в окружение

    local question = {}        -- разметка всего вопроса

    local questionContent = {} -- содержимое вопроса
    local hint = nil           -- подсказка
    local stems = nil          -- варианты ответа
    -- quarto.log.output(div)
    for _, el in ipairs(div.content) do
        if el.t == "BlockQuote" then
            hint = el.content
        elseif el.t == "OrderedList" or el.t == "BulletList" then
            stems = el
        else
            table.insert(questionContent, el)
        end
    end

    local gateName = ""
    -- имя гейта
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    local correctAnswersCount = 0 -- количество правильных ответов
    local wrongAnswerValue = 0    -- первое значения для неправильного ответа (увеличивается на -1000)
    local questionOptions = {}    -- список всех ответов
    for i, item in ipairs(stems.content) do
        local fullStem = {}       -- вариант ответа со всей разметко Alpinejs
        local option = {}
        local qHint = nil
        local qId = RandomStringID(10) -- id для label

        -- ищем в вопросе параграфы и блок-цитату
        for _, block in ipairs(item) do
            if block.t == "Para" or block.t == "CodeBlock" or block.t == "Image" or block.t == "Plain" then
                table.insert(option, block) -- параграфы сохраняем в список
            elseif block.t == "BlockQuote" then
                qHint = block               -- содержимое цитаты станет подсказкой к ответу
            end
        end

        local inputValue = 0
        local hintStyle = "qmulti__wrong_result"
        local isCorrect = "false"

        if option[1].content[1].text == "☒" then
            correctAnswersCount = correctAnswersCount + 1
            inputValue = correctAnswersCount
            hintStyle = "qmulti__correct_result"
            isCorrect = "true"
            -- quarto.log.output(correctAnswersCount) -- это правильный ответ
        else
            wrongAnswerValue = wrongAnswerValue - 1000
            inputValue = wrongAnswerValue
            -- quarto.log.output(wrongAnswerValue)
        end

        -- удаление символов ☒ и ☐ из дерева элементов
        option[1] = option[1]:walk({
            Str = function(elem)
                if string.match(elem.text, "[☒☐]") ~= nil then
                    return pandoc.Span('')
                else
                    return elem
                end
            end
        })

        table.insert(fullStem,
            pandoc.RawBlock("html",
                [[<div class="qmulti__stem"
                        :class="isChecked && isCorrectAnswer && isAnswered ? 'qmulti__correct' : !isCorrectAnswer && isChecked && isAnswered ? 'qmulti__wrong' : '' "
                        x-data="{isChecked: false, isCorrectAnswer: Number($refs.variant.value)>0}">
                        <label for="]] .. qId .. [[" >]]))
        table.insert(fullStem, pandoc.Div(option))
        table.insert(fullStem, pandoc.RawBlock("html", [[</label>
                <input
                    type="checkbox"
                    class="form-check-input"
                    id="]] .. qId .. [["
                    x-ref="variant"
                    value="]] .. inputValue .. [["
                    x-model="answers"
                    :disabled="isAnswerCorrect"
                    x-on:click="isAnswered = false; isChecked = $refs.variant.checked;"
                />
                </div>]]))

        if qHint ~= nil then
            table.insert(fullStem, pandoc.RawBlock("html",
                [[<div class="]] ..
                hintStyle ..
                [[" x-show="answers.includes(']] .. inputValue .. [[') && isAnswered" x-transition>]]
            ))
            table.insert(fullStem, pandoc.Div(qHint.content))
            table.insert(fullStem, pandoc.RawBlock("html", [[</div>]]))
        end

        table.insert(questionOptions, pandoc.Div(fullStem))
    end

    -- пропускаем рендеринг вопроса, если нет формулировки вопроса, списка ответов или в нём только 1 вариант
    -- или среди вариантов ответа нет правильных
    if #questionContent == 0 or stems == nil or #stems.content < 2 or correctAnswersCount == 0 then
        return pandoc
            .Div('')
    end

    -- открывающий div; есть отдельный стиль, если ответили с первой попытки
    table.insert(question,
        pandoc.RawBlock("html",
            [[<div class="qmulti" :class="isAnswerCorrect && attempt === 1 && 'qmulti_first_try'"
                x-data="{
                    answers: [],
                    isAnswered: false,
                    attempt: 0,
                    isAnswerCorrect: false,
                    isHintVisible: false
                }"
                data-gate=']] .. gateName .. [['
                x-init="$watch('isAnswerCorrect', value => {
                    if (value) {
                        isCurrentAnswerCorrect = true;
                        $dispatch('answer-notification', {
                            isCorrect: true,
                            type: 'qcheck',
                            gate: ']] .. gateName .. [[',
                            attempt: attempt
                        });
                    }
                })"
            >]]))

    if hint ~= nil then
        buttonsHtml =
        [[<button class="qmulti__hint_button"
                    type="button"
                    x-show="!isHintVisible && attempt >= 1 && !isAnswerCorrect" x-transition
                    x-on:click="isHintVisible=!isHintVisible">
                    ?
                </button>]]
        table.insert(question,
            pandoc.RawBlock("html", buttonsHtml))
    end

    table.insert(question, pandoc.RawBlock("html", [[<div
        x-show="isAnswerCorrect"
        x-transition
        x-cloak class="qmulti__result__badge qmulti__result__correct">
    <span>✔</span></div>]]))

    table.insert(question, pandoc.RawBlock("html", [[<div
        x-show="!isAnswerCorrect && isAnswered"
        x-transition
        x-cloak class="qmulti__result__badge qmulti__result__partial">
    <span>±</span></div>]]))

    table.insert(question, pandoc.Div(questionContent, { class = "qmulti__question" }))
    table.insert(question, pandoc.RawBlock("html", [[<hr class="hr-text" data-content="?">]]))

    if hint ~= nil then
        table.insert(question, pandoc.RawBlock("html", [[<div x-show="isHintVisible" x-transition>]]))
        table.insert(question, pandoc.Div(hint))
        table.insert(question, pandoc.RawBlock("html", [[</div>]]))
    end

    -- TODO вставить вопросы с отзывами
    ShuffleInPlace(questionOptions)
    table.insert(question, pandoc.Div(questionOptions))

    -- TODO число 3 заменить на сумму значений правильных ответов (арифметическая прогрессия)
    local correctSum = math.floor((correctAnswersCount + correctAnswersCount ^ 2) / 2)
    table.insert(question, pandoc.RawBlock("html", [[
            <button
                class="button__evaluate"
                x-show="!isAnswerCorrect"
                x-transition
                x-on:click="
                isAnswered = answers.length !== 0;
                isAnswerCorrect = answers.reduce((acc, cur)=> acc + Number(cur), 0) === ]] .. correctSum .. [[;
                attempt = isAnswered ? attempt + 1: attempt;"
            >
                ✓ Проверить
            </button>
            ]]))

    table.insert(question, pandoc.RawBlock("html", [[</div>]])) -- закрывающий div

    return pandoc.Div(question, { class = "qcheck__formated" })
end

function createQsolution(div)
    writeEnvironments()                   -- убеждаемся, что скрипты и стили добавлены в окружение
    local solution = {}                   -- итоговая разметка
    local solutionId = RandomStringID(10) -- id для div c решением

    local hintsList = nil
    local solutionCode = nil

    for _, el in ipairs(div.content) do
        if el.t == "OrderedList" or el.t == "BulletList" then
            hintsList = el.content
        elseif el.t == "CodeBlock" then
            solutionCode = el
        end
    end

    -- в блоке нет ни советов, ни кода решения скипаем
    if hintsList == nil and solutionCode == nil then
        return pandoc.Div('')
    end

    local numberOfhints = 0 -- количество подсказок
    if hintsList ~= nil then numberOfhints = #hintsList end

    -- главный div
    table.insert(solution, pandoc.RawBlock("html", [[<div
                x-data="{
                    visibleHintIndex: 0,
                    isSolutionVisible: false,
                    get isSolutionActive(){
                        return this.visibleHintIndex === ]] .. numberOfhints .. [[
                    }
                }"
            >]]))

    if hintsList ~= nil then
        for i, item in ipairs(hintsList) do
            table.insert(solution, pandoc.RawBlock("html", [[<div
                        x-transition
                        x-cloak
                        x-show="visibleHintIndex >= ]] .. i .. [["
                    >
                    <hr class="hr-text" data-content="💡">
                ]]))
            table.insert(solution, pandoc.Div(item))
            table.insert(solution, pandoc.RawBlock("html", [[</div>]]))
        end

        table.insert(solution, pandoc.RawBlock("html", [[
                <div class="solution__button__container">
                    <button
                    class="solution__button"
                    x-transition
                    x-transition:leave.duration.400ms
                    x-show="visibleHintIndex < ]] .. numberOfhints .. [["
                    x-on:click="visibleHintIndex++"
                >
                    💡 Получить подсказку
                </button>
                </div>
                ]]))
    end

    if solutionCode ~= nil then
        -- компонент для вывода кода решения
        table.insert(solution, pandoc.RawBlock("html", [[
                <div class="solution__button__container">
                    <button
                    class="solution__button"
                    x-cloak
                    x-transition
                    x-transition:enter.delay.450ms
                    x-show="isSolutionActive && !isSolutionVisible"
                    x-on:click="isSolutionVisible = true"
                >
                    🗝️ Получить решение
                </button>
                </div>
                ]]))
        table.insert(solution, pandoc.RawBlock("html", [[
                <div
                    id="]] .. solutionId .. [["
                    x-show="isSolutionVisible"
                    x-cloak
                    x-transition
                    x-transition:enter.duration.400ms
                    x-data="{
                    codeLines: [],
                    maskedSpans: [],
                    currentLine: -1,
                    }
                    "
                    x-init="$watch('currentLine', (value) => {
                        if (currentLine <= maskedSpans.length - 1) maskedSpans[value].classList.remove('code__mask');
                    });
                        const linesOfCode = Array.from(document.querySelectorAll('div#]] ..
            solutionId .. [[ code>span'));
                        const filteredArray = linesOfCode.filter((line)=>{
                            return line.childNodes.length > 1; // ищем не пустые строки кода
                        });
                        codeLines = filteredArray;
                        codeLines.forEach((line) => {
                            const lineLink = line.querySelector('a'); //ссылка внутри строки кода
                            const link = lineLink; // сохраняем копию ссылки
                            lineLink.remove(); // удаляем ссылку
                            const content = line.innerHTML; // разметка строки кода без ссылки
                            const leadingSpaces = content.match(/^\s*/)[0]; // поиск пробелов и знаков табуляции

                            const newSpan = document.createElement('span'); // элемент-оболочка для строки кода
                            newSpan.classList.add('code__mask'); // скрываем элемент
                            maskedSpans.push(newSpan); // сохраняем элемент в массив замаскированных строк
                            newSpan.innerHTML = content.trimStart(); // удаляем пробелы в начале строки кода
                            line.innerHTML = ''; // очищаем span со строкой кода
                            line.insertAdjacentElement('afterbegin', link); // возвращаем ссылку
                            line.insertAdjacentText('beforeend', leadingSpaces); // добавляем нужно количество пробелов
                            line.insertAdjacentElement('beforeend', newSpan); // добавляем элемент-оболочку
                        });
                    "
                >
                <hr class="hr-text" data-content="🗝️">
            ]]))
        table.insert(solution, solutionCode)
        table.insert(solution, pandoc.RawBlock("html", [[
                <button
                class="solution__button"
                x-transition
                x-transition:leave.duration.300ms
                x-show="currentLine < maskedSpans.length - 1"
                x-on:click="currentLine++"
            >
                Следующий шаг решения
            </button>
            <button
            class="solution__button full_solution"
            x-transition
            x-transition:leave.delay.350ms
            x-transition:leave.duration.300ms
            x-cloak
            x-show="currentLine >= 9 && currentLine < maskedSpans.length - 1"
            x-on:click="
                maskedSpans.forEach(line => line.classList.remove('code__mask'));
                currentLine = maskedSpans.length;
            ">🗝️ Показать всё решение</button>
            </div>
            ]]))
    end
    -- quarto.log.output(solution)

    -- закрываем главный div
    table.insert(solution, pandoc.RawBlock("html", [[</div>]]))
    return pandoc.Div(solution)
end

function createQgroup(div)
    local qList = {} -- список вопросов в группе
    local group = {} -- содержимое готовой группы вопросов
    local count = 0  -- количество вопросов в группе

    local gateName = ""
    -- имя гейта
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    for i, q in ipairs(div.content) do
        if q.classes ~= nil and (q.classes:includes("qmulti__formated") or
                q.classes:includes("qcheck__formated") or
                q.classes:includes("qinput__formated")) then
            table.insert(qList, pandoc.RawBlock("html", [[
            <div
                x-show="currentIndex === ]] .. (i - 1) .. [["
                x-transition
                x-cloak
            >]]))
            table.insert(qList, q)
            table.insert(qList, pandoc.RawBlock("html", [[</div>]]))

            count = count + 1
        end
    end

    table.insert(group, pandoc.RawBlock("html", [[
    <div
    x-data="{
        currentIndex: 0,
        totalSlides: ]] .. count .. [[,
        isCurrentAnswerCorrect: false,
        isQuizFinished: false,
        get progress(){
           return this.isQuizFinished ?
           100 :
           this.currentIndex * 100 / this.totalSlides;
        },
        next() {
            this.currentIndex = (this.currentIndex + 1) % this.totalSlides;
        },
        prev() {
            this.currentIndex = (this.currentIndex - 1 + this.totalSlides) % this.totalSlides;
        },
        reset() {
            this.currentIndex = 0;
        }
    }"
    data-gate=']] .. gateName .. [['
    x-init="$watch('isCurrentAnswerCorrect', value => {
        if(value && currentIndex === totalSlides - 1 ){
            isQuizFinished = true;
            $dispatch('answer-notification', {
                isCorrect: true,
                type: 'qgroup',
                gate: ']] .. gateName .. [[',
                attempt: 1
            });
        }
    })"
    >
    <div class="qgroup__header">
        <span x-text="`Вопрос ${currentIndex + 1} из ${totalSlides}`"></span>
    <button
        :class="isCurrentAnswerCorrect ? 'qgroup__pusle': ''"
        x-show="!isQuizFinished && (currentIndex + 1 < totalSlides)"
        x-transition
        :disabled="!isCurrentAnswerCorrect"
        x-on:click="next(); isCurrentAnswerCorrect = false"
    >
        Следующий вопрос ▷
    </button>
    <div x-show="isQuizFinished">
        <button x-on:click="prev">◁</button>
        <button x-on:click="next">▷</button>
    </div>
    </div>
    <div class="qgroup__progress_bar" :style="`width:${progress}%`">&nbsp;</div>
    ]]))
    table.insert(group, pandoc.Div(qList))

    table.insert(group, pandoc.RawBlock("html", [[
    <div class="qgroup__buttons">
    </div>
    ]]))

    table.insert(group, pandoc.RawBlock("html", [[</div>]]))

    return pandoc.Div(group, { class = "qgroup__ready" })
end

function createQflashcards(div)
    writeEnvironments()       -- убеждаемся, что скрипты и стили добавлены в окружение

    local elementContent = {} -- разметка всего вопроса

    local list = nil          -- варианты ответа
    -- quarto.log.output(div)
    for _, el in ipairs(div.content) do
        if el.t == "OrderedList" or el.t == "BulletList" then
            list = el
        end
    end

    if list == nil then return pandoc.Div('') end -- внутри элемента нет списков

    -- перебрать элементы списка
    local questionsNumber = 0

    local cardsList = {} -- список отформатированных карточек
    for i, listE in ipairs(list.content) do
        local questionContent = {}
        local answerContent = nil

        for _, block in ipairs(listE) do
            if block.t == "Para" or block.t == "CodeBlock" or block.t == "Image" or block.t == "Plain" then
                table.insert(questionContent, block) -- параграфы сохраняем в список
            elseif block.t == "BlockQuote" then
                answerContent = block                -- содержимое цитаты станет подсказкой к ответу
            end
        end
        if answerContent == nil then return pandoc.Div('') end -- есть вопрос без ответа

        questionsNumber = questionsNumber + 1                  -- считаем количество вопросов

        table.insert(cardsList, pandoc.RawBlock("html", [[
        <div
          class="qflashcards__card card"
          x-cloak
          x-data="{
            isAnswerd: false,
            showAnswer(){
              this.isAnswerd = true;
            },
            recall(){
              this.isAnswerd=false;
              addToRecall();
            },
            remembered(){
              this.isAnswerd=false;
              addToRemembered();
            }
          }"
          x-show="isVisible(]] .. (i - 1) .. [[)" :style="getCardStyle(]] .. (i - 1) .. [[)"
        >
          <div class="qflashcards__question">
        ]]))
        table.insert(cardsList, pandoc.Div(questionContent));
        table.insert(cardsList, pandoc.RawBlock("html", [[
            <hr class="hr-text" data-content="?">
            <button
                x-show="!isAnswerd"
                x-on:click="showAnswer">
                Показать ответ
            </button>
        </div>
        <div x-show="isAnswerd" x-transition x-cloak class="qflashcards__answer">
        ]]))

        table.insert(cardsList, pandoc.Div(answerContent.content))
        table.insert(cardsList, pandoc.RawBlock("html", [[
            <div class="qflashcards__card__buttons">
              <button :disabled="!isAnswerd" class="button__recall"
                x-on:click.stop="recall">
                Не помню</button>
              <button :disabled="!isAnswerd" class="button_remember"
              x-on:click.stop="remembered">
                Помню</button>
            </div>
          </div>
        </div>
        ]]))
    end

    -- в таблицу cardsList добавить разметку одной карточки

    -- сформировать разметку компонента
    table.insert(elementContent, pandoc.RawBlock("html", [[
    <div
      class="qflashcards__container"
      x-data="{
        attempt: 0,
        currentCardIndex: 0,
        totalCards: ]] .. questionsNumber .. [[,
        startingQ: [...Array(]] .. questionsNumber .. [[).keys()],
        recallQ: [],
        rememberedQ: [],
        hardQ: [],
        isFinished: false,
        init(){
            this.attempt = 0;
            this.recallQ = [];
            this.rememberedQ = [];
            this.hardQ = [];
            this.isFinished = false;
            this.currentCardIndex = this.startingQ.shift();
        },
        addToRemembered(){
            this.rememberedQ.push(this.currentCardIndex);
            this.newCardIndex();
        },
        addToRecall(){
            this.recallQ.push(this.currentCardIndex);
            if (!this.hardQ.includes(this.currentCardIndex)) {
            this.hardQ.push(this.currentCardIndex);
            }
            this.newCardIndex();
        },
        newCardIndex(){
            this.attempt++;

            if (this.startingQ.length !== 0){
                this.currentCardIndex = this.startingQ.shift();
            } else if (this.recallQ.length !== 0){
                this.currentCardIndex = this.recallQ.shift();
            } else {
                this.isFinished = true;
            }
        },
        get isFirstTry() {
            return this.isFinished && this.attempt === ]] .. questionsNumber .. [[;
        },
        reset(){
            this.startingQ = [...this.hardQ, ...this.rememberedQ.filter(cardId=>{
                return !this.hardQ.includes(cardId);
            })];
            this.init();
        },
        get cardsRemaining(){
            return this.recallQ.length + this.startingQ.length + 1
        },
        isVisible(index) {
            return (index - this.currentCardIndex + this.totalCards) % this.totalCards < 3;
        },
        getCardStyle(index) {
            const offset = (index - this.currentCardIndex + this.totalCards) % this.totalCards;
            return {
                transform: `translateY(${offset*0.8}em) scale(${1 - offset * 0.05})`,
                opacity: offset === 0 ? 1 : 0.6,
                zIndex: this.totalCards - offset
            };
        }
    }"
    >
    <div x-show="!isFinished" x-transition.duration.500ms>
      <p class="qflashcars__header" x-text="`Осталось карточек: ${cardsRemaining}`"></p>
    ]]))

    -- добавить разметку карточек
    table.insert(elementContent, pandoc.Div(cardsList, { class = "qcard-stack" }))

    -- добавить разметку кнопки сброса
    table.insert(elementContent, pandoc.RawBlock("html", [[
    </div>
      <div x-show="isFinished"
        x-transition.duration.500ms
        x-cloak
        class="qflashcards__results">
        <button x-on:click="reset">Повторить ещё раз</button>
      </div>
    </div>
    ]]))
    -- вернуть elementContent из функции

    return pandoc.Div(elementContent, { class = "qflashcards__ready" })
end

-- в мультистрочном блоке инструкций
-- удаляем начальные пробелы в каждой строке
function trim_initial_spaces(input)
    -- Разбиваем строку на строки по символу новой строки
    local lines = {}
    for line in input:gmatch("[^\r\n]+") do
        -- Удаляем начальные пробелы
        line = line:gsub("^%s+", "")
        table.insert(lines, line)
    end

    -- Объединяем строки обратно в одну строку с символом новой строки
    return table.concat(lines, "\n")
end

local function escapeHtmlDataAttribute(str)
    local entities = {
        ['"'] = "&quot;",
        ["'"] = "&#39;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ["&"] = "&amp;",
        [" "] = "&#32;",
        ["\t"] = "&#9;",
        ["\n"] = "&#10;",
        ["\r"] = "&#13;"
    }

    return str:gsub('[&<>"\'\t\n\r ]', function(c)
        return entities[c] or c
    end)
end

function createQParson(div)
    writeEnvironments()              -- убеждаемся, что скрипты и стили добавлены в окружение

    local taskID = RandomStringID(7) -- уникальный идентификатор задания

    local elementContent = {}        -- разметка всего вопроса
    local solutionCode = nil         -- варианты ответа
    local distractors = nil          -- элемент CodeBlock содержащий дистракторы для усложнения задания

    local spacesPerLevel = 4         -- количество пробелов на один уровень отступов в коде
    -- берём количество пробелов из атрибута spaces, если такой указан в разметке div блока
    if div.attributes["spaces"] ~= nil then
        spacesPerLevel = div.attributes["spaces"]
    end

    local separator = "[^\r\n]+" -- начальный шаблон для разделения строк кода; изначально - перенос строки
    if div.attributes["sep"] ~= nil then
        -- создаём шаблон на основе переданной через атрибут sep строки
        separator = "(.-)(" .. div.attributes["sep"] .. "?)\n"
    end

    for _, el in ipairs(div.content) do
        if el.t == "CodeBlock" then
            if solutionCode == nil then
                solutionCode = el
            else
                distractors = el
            end
        end
    end

    if solutionCode == nil then return pandoc.Div('') end -- внутри qparson нет кода решения; завершаем работу функции

    lines = {}
    for s in (solutionCode.text .. "\n"):gmatch(separator) do --"[^\r\n]+"
        table.insert(lines, s)
    end

    -- если есть дистракторы, добавляем их к блокам решения
    if distractors ~= nil then
        for s in (distractors.text .. "\n"):gmatch(separator) do --"[^\r\n]+"
            table.insert(lines, s)
        end
    end

    -- TODO УДАЛЯТЬ ПУСТЫЕ СТРОКИ

    -- определяем, какие блоки должны сами быть контейнерами для, а какие просто
    -- блоками для перетаскивания
    local isLineBlock = {}
    for i = 1, (#lines - 1) do
        currentLineSpaces = count_leading_spaces(lines[i])
        nextLineSpaces = count_leading_spaces(lines[i + 1])

        if nextLineSpaces > currentLineSpaces then
            table.insert(isLineBlock, 1)
        else
            table.insert(isLineBlock, 0)
        end
    end
    table.insert(isLineBlock, 0) -- последняя строка кода всегда не будет блоком

    local itemsList = {}         -- список элементов для перетаскивания
    for i = 1, #lines do
        local itemRawHTML = ""
        local trimedLine = trim_initial_spaces(lines[i]) --lines[i]:gsub("^%s+", "")
        local level = #(lines[i]:match("^(%s*)")) // spacesPerLevel
        if isLineBlock[i] == 0 then
            itemRawHTML = [[
<div class="sort-item" data-level="]] ..
                level ..
                [[" x-sort:item="]] ..
                i .. [["><code data-code-line="]] .. escapeHtmlDataAttribute(lines[i]) .. [[">]] ..
                trimedLine .. [[</code></div>]]
        else
            itemRawHTML = [[
<div class="sort-item" data-level="]] .. level .. [[" x-sort:item="]] .. i .. [[">
    <code data-code-line="]] .. escapeHtmlDataAttribute(lines[i]) .. [[">]] .. trimedLine .. [[</code>
    <div class="code-block"
        x-sort.ghost
        x-sort:config="{ filter: ()=>{return isAnswered ? 'sort-item' : ''}, swapThreshold: 0.65}"
        x-sort:group="code-]] .. taskID .. [["
        x-sort="isShowFeedback = false"
        >
        <div class="empty-item" x-sort:item="999"></div>
    </div>
</div>]]
        end
        table.insert(itemsList, itemRawHTML)
    end

    ShuffleInPlace(itemsList) -- перемешиваем строки с кодом программы

    local solutionText = solutionCode.text
    if div.attributes["sep"] ~= nil then
        solutionText = solutionCode.text:gsub(div.attributes["sep"], "")
    end

    table.insert(elementContent, pandoc.RawBlock("html", [[
<div
      x-data="{
      isAnswered: false,
      isShowFeedback: false,
      attempt: 0,
      parse(el){
        this.attempt++;
        const solution = $refs.solutionPre.innerText;

        const lines = Array.from(el.querySelectorAll('code')); // получаем список строк кода в теге code
        const itemDivs = lines.map((line)=>{return line.parentElement}); // список родительских элементов тегов code

        const levelCorrelationList = []; // массив булевых значений уровней вложенности

        /*
        Выясняем, находится ли строка кода в блоке с правильным уровнем отступа.
        */
        itemDivs.forEach((elmnt)=>{
          let levelsCounter = 0;
          let currentParrent = elmnt.parentElement;
          // перебираем родительские элементы пока они не существуют или не встретим контейнер с решением
          while(currentParrent !== null && !currentParrent.className.includes('block-container')){
            // нашли среди родителей блок с классом sort-item
            // значит нашли ещё один уровень вложенности
            if (currentParrent.className.includes('sort-item')){
              levelsCounter++;
            }
            currentParrent = currentParrent.parentElement;
          }
          // сравниваем
          levelCorrelationList.push(Number(elmnt.getAttribute('data-level')) === levelsCounter);
        });

        // формируем список строк кода
        const code = lines.map((line)=>{
          return line.getAttribute('data-code-line');
        });
        const fullCodeSolution = code.join('\n');

        this.isShowFeedback = true; // показать фидбек по вопросу
        this.isAnswered = fullCodeSolution === solution && !levelCorrelationList.includes(false);
      }
    }"
    > <!-- Начало компонента AlpineJs -->

    <!-- скрытый элемент pre с правильным кодом решениям -->
    <pre style="display: none;" x-ref="solutionPre">]] .. solutionText .. [[</pre>

    <div class="header__buttons">
        <div x-show="isAnswered" x-cloak x-transition>
            <button class="copy_code" x-on:click="navigator.clipboard.writeText($refs.solutionPre.innerText)">📋</button>
            <div
                class="qparson__result__badge">
                <span>✔</span>
            </div>
        </div>

        <button x-show="!isAnswered" x-on:click="parse($refs.result)">Проверить</button>
    </div>
    <div class="block__container"> <!-- grid start -->
      <div
        x-sort.ghost
        x-sort:config="{ filter: ()=>{return isAnswered ? 'sort-item' : ''}, swapThreshold: 0.65}"
        x-sort:group="code-]] .. taskID .. [["
        x-sort="isShowFeedback = false"
        class="block-container source"
      >
        <div class="empty-item" x-sort:item="999"></div>
]]))

    table.insert(elementContent, pandoc.RawBlock("html", table.concat(itemsList, "")))
    table.insert(elementContent, pandoc.RawBlock("html", [[
    </div>
    <div
        x-sort.ghost
        x-sort:config="{ filter: ()=>{return isAnswered ? 'sort-item' : ''}, swapThreshold: 0.65}"
        x-sort:group="code-]] .. taskID .. [["
        x-sort="isShowFeedback = false"
        class="block-container solution"
        x-ref="result"
    >
        <div class="empty-item" x-sort:item="999"></div>
    </div>
    </div> <!-- flex end -->
    <div class="feedback__container" x-show="isShowFeedback === true" x-cloak x-transition>
        <div x-cloak x-transition x-show="!isAnswered" class="qmulti__wrong_result">В коде есть ошибки</div>
    </div>
</div>
]]))

    return pandoc.Div(elementContent, { class = "qparson__ready" })
end

function createQgate(div)
    local name = nil
    -- берём количество пробелов из атрибута spaces, если такой указан в разметке div блока
    if div.attributes["name"] ~= nil then
        name = div.attributes["name"]
    else
        return nil
    end

    local elementContent = {}
    table.insert(elementContent, pandoc.RawBlock("html", [[
    <div x-data="{
        gateCount: null,
        init(){
            this.gateCount = document.querySelectorAll('[data-gate=]] .. name .. [[]').length
    },
        get isVisible(){
            return this.gateCount !== null && this.gateCount <= 0;
        }

    }" x-on:answer-notification.window="
        const isCorrect = $event.detail.isCorrect;
        const gate = $event.detail.gate;
        if(isCorrect && ']] .. name .. [[' === gate){
            gateCount--;
        }
    ">
    <div x-show="isVisible" x-cloak x-transition:enter.duration.2000ms x-transition.delay.500ms>
    ]]))
    table.insert(elementContent, div)
    table.insert(elementContent, pandoc.RawBlock("html", [[
    </div>
    </div>
    ]]))

    return pandoc.Div(elementContent, { class = "qgate__ready" })
end

if quarto.doc.isFormat("html:js") then
    Div = function(div)
        -- # Вопрос с одним правильным ответом # --
        if div.classes:includes("qmulti") then -- если div содержит нужный стиль - обрабатываем разметку
            return createQmutli(div)
        end

        -- # Вопрос с несколькими правильными ответами # --
        if div.classes:includes("qcheck") then -- если div содержит нужный стиль - обрабатываем разметку
            return createQcheck(div)
        end

        -- # Вопрос с несколькими правильными ответами # --
        if div.classes:includes("qinput") then -- если div содержит нужный стиль - обрабатываем разметку
            return createQinput(div)
        end

        -- # Подсказки и решение задачи # --
        if div.classes:includes("qsolution") then -- если div содержит нужный стиль - обрабатываем разметку
            return createQsolution(div)
        end

        if div.classes:includes("qgroup") then -- если div содержит нужный стиль - обрабатываем разметку
            return createQgroup(div)
        end

        if div.classes:includes("qflashcards") then -- если div содержит нужный стиль - обрабатываем разметку
            return createQflashcards(div)
        end

        if div.classes:includes("qparson") then
            return createQParson(div)
        end

        -- # Ворота # --
        if div.classes:includes("qgate") then -- если div содержит нужный стиль - обрабатываем разметку
            return createQgate(div)
        end

        return nil
    end
end
