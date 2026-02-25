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
                q.classes:includes("qinput__formated")) or
            q.classes:includes("qparson__ready") or
            q.classes:includes("qspot__formated") then
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
    local taskDescription = {}       -- разметка условия задачи
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

    local gateName = "" -- имя гейта

    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    for _, el in ipairs(div.content) do
        if el.t == "CodeBlock" then
            if solutionCode == nil then
                solutionCode = el
            else
                distractors = el
            end
        else
            table.insert(taskDescription, el) -- все остальные элементы добавляем в условие задачи
        end
    end

    if solutionCode == nil then return pandoc.Div('') end -- внутри qparson нет кода решения; завершаем работу функции

    -- язык подстветки кода
    local languageClass = "python"
    if #solutionCode.classes > 0 then
        languageClass = solutionCode.classes[1]
    end

    lines = {}
    for s in (solutionCode.text .. "\n"):gmatch(separator) do --"[^\r\n]+"
        table.insert(lines, s)
    end

    local correctLinesString = escapeHtmlDataAttribute(table.concat(lines, [[`, `]]))

    -- если есть дистракторы, добавляем их к блокам решения
    if distractors ~= nil then
        for s in (distractors.text .. "\n"):gmatch(separator) do --"[^\r\n]+"
            table.insert(lines, s)
        end
    end

    -- TODO УДАЛЯТЬ ПУСТЫЕ СТРОКИ

    -- определяем, какие блоки должны сами быть контейнерами для других блоков, а какие просто
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
    table.insert(isLineBlock, 0)                         -- последняя строка кода всегда не будет блоком

    local itemsList = {}                                 -- список элементов для перетаскивания
    for i = 1, #lines do
        local trimedLine = trim_initial_spaces(lines[i]) --lines[i]:gsub("^%s+", "")
        local level = #(lines[i]:match("^(%s*)")) // spacesPerLevel
        if isLineBlock[i] == 0 then
            local itemDivContent = {
                pandoc.RawBlock("html", [[<span data-code-line="]] .. escapeHtmlDataAttribute(lines[i]) .. [[">]]),
                pandoc.Code(trimedLine, { class = languageClass }),
                pandoc.RawBlock("html", [[</span>]])
            }
            table.insert(itemsList,
                pandoc.Div(itemDivContent,
                    { class = "sort-item", ['data-level'] = tostring(level), ['x-sort:item'] = tostring(i) }))
        else
            local itemDivContent = {
                pandoc.RawBlock("html", [[<span data-code-line="]] .. escapeHtmlDataAttribute(lines[i]) .. [[">]]),
                pandoc.Code(trimedLine, { class = languageClass }),
                pandoc.RawBlock("html", [[</span>
                    <div class="code-block"
                        x-sort.ghost
                        x-sort:config="{ filter: ()=>{return isAnswered ? 'sort-item' : ''}, swapThreshold: 0.65}"
                        x-sort:group="code-]] .. taskID .. [["
                        x-sort="isShowFeedback = false"
                        >
                        <div class="empty-item" x-sort:item="999"></div>
                    </div>]])
            }
            table.insert(itemsList,
                pandoc.Div(itemDivContent,
                    { class = "sort-item", ['data-level'] = tostring(level), ['x-sort:item'] = tostring(i) }))
        end
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
      maxHeight: 0,
      linesArray: [`]] .. correctLinesString .. [[`],
      errorMessage: 'В коде есть ошибка.',
      feedback(){
        this.attempt++; // счётчик попыток
        this.isShowFeedback = true; // показать фидбек по вопросу
        // Обратная связь
        // Массив блоков в области решения
        const sortItems = Array.from($el.querySelectorAll('.solution .sort-item'));

        // список элементов в области source, убираем класс error
        const sourceSortItems = Array.from($el.querySelectorAll('.source .sort-item'));
        sourceSortItems.forEach((sI, index)=>{
            sI.classList.remove('error');
        });

        const isSolutionLengthCorrect = this.linesArray.length === sortItems.length;
        if (!isSolutionLengthCorrect){
            this.errorMessage = 'В решении задачи не хватает блоков.';
        }

        // перебираем блоки в области решения
        let correctFlag = true;

        sortItems.forEach((sI, index)=>{
            sI.classList.remove('error');
            if(this.isShowFeedback){
                const itemSortIndex = Number(sI.getAttribute('x-sort:item'));

                const blockLevel = Number(sI.getAttribute('data-level'));

                /*
                Чтобы узнать корректность вложенности блока, обращаемся к родительскому блоку.
                Смотрим на атрибут data-level. Для корректно вложенных блоков разность уровней
                должна быть равна единице.
                */
                let parent = sI.parentElement;
                let guardCounter = 10; // счётчик-защита от зацикливания
                while(!parent.getAttribute('data-level') && guardCounter > 0){
                    parent = parent.parentElement;
                    guardCounter--;
                }
                const parentBlockLevel = Number(parent.getAttribute('data-level'));

                const code = sI.querySelector('span[data-code-line]').getAttribute('data-code-line');

                // ошибка, если не соблюдается порядок расположения или уровень вложенности блока
                if((blockLevel - parentBlockLevel) !== 1 ||
                    code !== this.linesArray[index]){
                    sI.classList.add('error');
                    this.errorMessage = 'Неправильный порядок расположения блоков.';
                    correctFlag = false;
                }
                else
                    sI.classList.remove('error');
            }
        });

        this.isAnswered = correctFlag && isSolutionLengthCorrect;
      },
    }"
    data-gate=']] .. gateName .. [['
    x-init="const targetNode = $el;

    // если меняется высота всего компонента, пересчитываем высоту блока
    // который хранит строки кода
    // это нужно, если элемент используется в qgroup или qgate
    const observer = new ResizeObserver(entries => {
        const codeBlocks = Array.from($el.querySelectorAll('.sort-item'));
        maxHeight = codeBlocks.reduce((acc, node)=>{
            return acc + node.offsetHeight;
        }, 15);
    });
    observer.observe(targetNode);

    $watch('isAnswered', value => {
        console.log(isAnswered);
        if (value) {
            isCurrentAnswerCorrect = true;
            $dispatch('answer-notification', {
                isCorrect: true,
                type: 'qparson',
                gate: ']] .. gateName .. [[',
                attempt: attempt
            });
        }
    });
    "> <!-- Начало компонента AlpineJs -->


    <div x-show="isAnswered" x-transition="" class="qmulti__result__badge qmulti__result__correct">
        <span>✔</span>
    </div>

    <!-- скрытый элемент pre с правильным кодом решениям -->
    <pre style="display: none;" x-ref="solutionPre">]] .. solutionText .. [[</pre>]]))

    -- рендеринг условия задачи, если оно есть
    if #taskDescription ~= 0 then
        table.insert(elementContent, pandoc.Div(taskDescription, { class = "task__desc" }))
    end

    table.insert(elementContent, pandoc.RawBlock("html",
        [[

    <div class="block__container"> <!-- grid start -->
      <div
      x-sort="(item, position) => { isShowFeedback = false }"
        x-sort.ghost
        x-sort:config="{ filter: ()=>{return isAnswered ? 'sort-item' : ''}, swapThreshold: 0.65}"
        x-sort:group="code-]] .. taskID .. [["

        class="block-container source"
        :style="`height: ${maxHeight}px`"
      >
        <div class="empty-item" x-sort:item="999"></div>
]]))

    --- добавляем перетаскиваемые элементы
    for _, el in ipairs(itemsList) do
        table.insert(elementContent, el)
    end

    table.insert(elementContent, pandoc.RawBlock("html", [[
    </div>
    <div
    x-sort="(item, position) => { isShowFeedback = false }"
        x-sort.ghost
        x-sort:config="{ filter: ()=>{return isAnswered ? 'sort-item' : ''}, swapThreshold: 0.65}"
        x-sort:group="code-]] .. taskID .. [["

        class="block-container solution"
        :style="`height: ${maxHeight}px`"
        x-ref="result"
        data-level="-1"
    >
        <div class="empty-item" x-sort:item="999"></div>
    </div>
    </div> <!-- flex end -->

    <div class="header__buttons">
        <div x-show="isAnswered" x-cloak x-transition>
            <button class="copy_code" x-on:click="navigator.clipboard.writeText($refs.solutionPre.innerText)">📋</button>
            <span x-text="`Использовано попыток: ${attempt}`"></span>
        </div>

        <button x-show="!isAnswered" x-on:click="feedback();">Проверить</button>

        <div x-show="isShowFeedback === true" x-cloak x-transition>
            <div x-cloak x-transition x-show="!isAnswered" class="qmulti__wrong_result">
                <span x-text="errorMessage"></span>
            </div>
        </div>
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
            this.gateCount = document.querySelectorAll('[data-gate=]] .. name .. [[]').length;
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
        <hr class="hr-text" :data-content="!isVisible ? `🔒 (${gateCount})` : '✅'">
    <div x-show="isVisible" x-cloak x-transition:enter.duration.2000ms x-transition.delay.500ms>
    ]]))
    table.insert(elementContent, div)
    table.insert(elementContent, pandoc.RawBlock("html", [[
    </div>
    </div>
    ]]))

    return pandoc.Div(elementContent, { class = "qgate__ready" })
end

function createQflip(div)
    writeEnvironments()              -- убеждаемся, что скрипты и стили добавлены в окружение

    local question = {}              -- разметка всего вопроса
    local questionContent = {}       -- содержимое вопроса
    local answerContent = {}         -- содержимое ответа

    local gateName = ""

    -- имя гейта
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    local isQuestion = true

    -- quarto.log.output(div)
    for _, el in ipairs(div.content) do
        if el.t == "HorizontalRule" then
            isQuestion = false
        elseif isQuestion then
            table.insert(questionContent, el)
        else
            table.insert(answerContent, el)
        end
    end

    if #questionContent == 0 or #answerContent == 0 then
        return pandoc
            .Div('')
    end

    table.insert(question, pandoc.RawBlock("html", [[<div class="qscene" x-data="{ flipped: false }">
      <div
        class="qcard"
        @click="flipped = !flipped"
        :class="{ 'is-flipped': flipped }"
      >
        <div class="qcard__face qcard__face--front">
          <div class="qcard__content">]]))

    table.insert(question, pandoc.Div(questionContent))

    table.insert(question, pandoc.RawBlock("html", [[</div>
            </div>

            <div class="qcard__face qcard__face--back">
            <div class="qcard__content">
    ]]))

    table.insert(question, pandoc.Div(answerContent))

    table.insert(question, pandoc.RawBlock("html", [[</div>
        </div>
      </div>
    </div>]]))

    return pandoc.Div(question, { class = "qflip__ready" })
end

function css_style(str)
    local top, left, width, height = str:match("(%-?%d+%.?%d*) (%-?%d+%.?%d*) (%-?%d+%.?%d*) (%-?%d+%.?%d*)")
    return string.format("style=\"top: %s%%; left: %s%%; width: %s%%; height: %s%%\"", top, left, width, height)
end

function createQspot(div)
    writeEnvironments() -- окружение
    local qId = RandomStringID(10) -- уникальный ID для элементов этого вопроса
    local question = {}        -- разметка всего вопроса

    local questionsContent = {}       -- список вопросов
    local mainImage = nil                 -- изображение
    local hint = nil           -- подсказка

    local area = ""
    if div.attributes["area"] ~= nil then
        area = pandoc.utils.stringify(div.attributes["area"])
    end

    local gateName = ""
    -- имя гейта
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    
    for _, el in ipairs(div.content) do

        if el.t == "BlockQuote" then
            hint = el.content
        elseif (el.t == "Figure" or el.t == "Para") 
            and el.content[1].t == "Image" and mainImage == nil then
            mainImage = el.content[1]
        else
            table.insert(questionsContent, el)
        
        end
    end

    -- нет нужных элементов в разметке вопроса
    if #questionsContent == 0 or mainImage == nil or area == '' then
        return pandoc
            .Div('')
    end


    table.insert(question, pandoc.RawBlock("html", [[
    <div class="qmulti" :class="isAnswerCorrect && attempt === 1 && 'qmulti_first_try'"
        x-data="{
            attempt: 0,
            isAnswerCorrect: false,
            isHintVisible: false,
            isShakeHead: false,
            shake(){
                this.isShakeHead = true;
                setTimeout(() => {
                    this.isShakeHead = false;
                }, 600);
            },
            isCorrectHit: false,
            hitTest(event){
                const container = document.querySelector('.qspot__container[data-qid=]]..qId..[[');
                const pin = document.querySelector('.qspot__pin[data-qid=]]..qId..[[');
                const area = document.querySelector('.qspot__area[data-qid=]]..qId..[[');
                event.stopPropagation();
                // Координаты клика в окне браузера
                const clickX = event.clientX;
                const clickY = event.clientY;

                // Прямоугольник контейнера (для расчёта положения пина)
                const containerRect = container.getBoundingClientRect();

                // Координаты клика относительно контейнера
                const relativeX = clickX - containerRect.left;
                const relativeY = clickY - containerRect.top;

                const percentX = (relativeX / containerRect.width) * 100;
                const percentY = (relativeY / containerRect.height) * 100;

                // Перемещаем пин (работает благодаря position: absolute у пина)
                pin.style.left = percentX + '%';
                pin.style.top = percentY + '%';

                // Прямоугольник области (в координатах окна)
                const areaRect = area.getBoundingClientRect();

                // Проверка попадания
                this.isCorrectHit =
                clickX >= areaRect.left &&
                clickX <= areaRect.right &&
                clickY >= areaRect.top &&
                clickY <= areaRect.bottom;

            }
        }"
        data-gate=']] .. gateName .. [['
        x-init="$watch('isAnswerCorrect', value => {
            if (value) {
                isCurrentAnswerCorrect = true;
                $dispatch('answer-notification', {
                    isCorrect: true,
                    type: 'qspot',
                    gate: ']] .. gateName .. [[',
                    attempt: attempt
                });
            }
        })">
    <div x-show="isAnswerCorrect" x-transition="" class="qmulti__result__badge qmulti__result__correct">
        <span>✔</span>
    </div>]]))

    -- текст вопроса и разделительная черта
    table.insert(question, pandoc.Div(questionsContent, { class = "qmulti__question" }))
    table.insert(question, pandoc.RawBlock("html", [[<hr class="hr-text" data-content="?">]]))

    -- разметка с текстом подсказки, если она есть
    if hint ~= nil then
        table.insert(question, pandoc.RawBlock("html", [[<div x-show="isHintVisible" x-transition>]]))
        table.insert(question, pandoc.Div(hint))
        table.insert(question, pandoc.RawBlock("html", [[</div>]]))
    end

    if hint ~= nil then
        buttonsHtml =
        [[<button class="qmulti__hint_button"
        type="button"
        x-show="!isHintVisible && attempt >= 1 && !isAnswerCorrect" x-transition
        x-on:click="isHintVisible=!isHintVisible">
        ?
        </button>]]
        table.insert(question, pandoc.RawBlock("html", buttonsHtml))
    end

    table.insert(question, pandoc.RawBlock("html", [[
    <p class="qspot__instruction">Кликните по изображению чтобы выбрать ответ.</p>
    <div class="qspot__container__wraper">
    
    <div data-qid="]]..qId..[[" class="qspot__container" x-on:click="hitTest($event)">
        <div data-qid="]]..qId..[[" class="qspot__area" :class="isAnswerCorrect && 'correct'" ]]..css_style(area)..[[></div>]]))

    table.insert(question, mainImage)

    table.insert(question, pandoc.RawBlock("html", [[
        <div data-qid="]]..qId..[[" class="qspot__pin" x-show="!isAnswerCorrect" :class="{ 'wrong': isShakeHead }" x-transition="">
        <img src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAEqWlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4KPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNS41LjAiPgogPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90aWZmLzEuMC8iCiAgICB4bWxuczpleGlmPSJodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyIKICAgIHhtbG5zOnBob3Rvc2hvcD0iaHR0cDovL25zLmFkb2JlLmNvbS9waG90b3Nob3AvMS4wLyIKICAgIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIKICAgIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIgogICAgeG1sbnM6c3RFdnQ9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZUV2ZW50IyIKICAgdGlmZjpJbWFnZUxlbmd0aD0iNjQiCiAgIHRpZmY6SW1hZ2VXaWR0aD0iNjQiCiAgIHRpZmY6UmVzb2x1dGlvblVuaXQ9IjIiCiAgIHRpZmY6WFJlc29sdXRpb249IjcyLzEiCiAgIHRpZmY6WVJlc29sdXRpb249IjcyLzEiCiAgIGV4aWY6UGl4ZWxYRGltZW5zaW9uPSI2NCIKICAgZXhpZjpQaXhlbFlEaW1lbnNpb249IjY0IgogICBleGlmOkNvbG9yU3BhY2U9IjEiCiAgIHBob3Rvc2hvcDpDb2xvck1vZGU9IjMiCiAgIHBob3Rvc2hvcDpJQ0NQcm9maWxlPSJzUkdCIElFQzYxOTY2LTIuMSIKICAgeG1wOk1vZGlmeURhdGU9IjIwMjYtMDIt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'/>
        </div>
    </div>
    </div>]]))

    table.insert(question, pandoc.RawBlock("html", [[
    <div>
            <button
                class="button__evaluate"
                x-show="!isAnswerCorrect"
                x-transition
                x-on:click="attempt++; isAnswerCorrect = isCorrectHit; if (!isCorrectHit) shake();"
            >
                ✓ Проверить
            </button>
    </div>
    </div>
            ]]))

    return pandoc.Div(question, { class = "qspot__formated" })
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

        if div.classes:includes("qflip") then
            return createQflip(div)
        end

        if div.classes:includes("qspot") then
            return createQspot(div)
        end

        -- # Ворота - обработка в последнюю очередь # --
        if div.classes:includes("qgate") then -- если div содержит нужный стиль - обрабатываем разметку
            return createQgate(div)
        end

        return nil
    end
end
