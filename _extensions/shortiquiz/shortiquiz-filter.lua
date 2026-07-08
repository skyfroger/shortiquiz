local EXTENSION_NAME = "shortiquiz"

local utils = require("./utils")
local l10n  = require("./localize")


function createQinput(div)
    utils.writeEnvironments()        -- loading all scripts and css stylesheets

    local question = {}              -- question markup

    local questionContent = {}       -- question content
    local hint = nil                 -- hint
    local stems = nil                -- question stems

    local gateName = ""

    -- gate name
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    for _, el in ipairs(div.content) do
        if el.t == "BlockQuote" then
            hint = el.content
        elseif el.t == "OrderedList" or el.t == "BulletList" then
            stems = el
        else
            table.insert(questionContent, el)
        end
    end

    -- skip question without content or stems
    if #questionContent == 0 or stems == nil or #stems.content < 1 then return pandoc.Div('') end

    local stemHints = {}
    local correctAnswer = nil
    for i, item in ipairs(stems.content) do
        local qHint = nil
        local answer = nil

        -- search for paragraphs and quote block
        for _, block in ipairs(item) do
            if block.t == "Para" or block.t == "Plain" then
                answer = block.content[1].text
            elseif block.t == "BlockQuote" then
                qHint = block -- content of the quote block will become a hint
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
    end

    -- opening div
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
            placeholder="]]..l10n("inputPlaceholder")..[["
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
        >✓ ]]..l10n("checkAnswer")..[[</button>
    </div>
    ]]))

    table.insert(question, pandoc.Div(stemHints))

    table.insert(question, pandoc.RawBlock("html", [[</div>]])) -- closing div

    return pandoc.Div(question, { class = "qinput__formated" })
end

function createQmutli(div)
    utils.writeEnvironments()              

    local question = {}              

    local questionContent = {}       
    local hint = nil                 
    local stems = nil                
    local qName = utils.RandomStringID(10) -- unique name for stems

    local gateName = ""

    -- gate name
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    for _, el in ipairs(div.content) do
        if el.t == "BlockQuote" then
            hint = el.content
        elseif el.t == "OrderedList" or el.t == "BulletList" then
            stems = el
        else
            table.insert(questionContent, el)
        end
    end

    -- skip rendering if question format is incorrect
    if #questionContent == 0 or stems == nil or #stems.content < 2 then return pandoc.Div('') end

    local stemHints = {}
    local questionOptions = {}
    for i, item in ipairs(stems.content) do
        local fullStem = {}    -- one stem with all Alpinejs markup
        local option = {}
        local qHint = nil
        local qId = utils.RandomStringID(10) -- id for label tag

        for _, block in ipairs(item) do
            if block.t == "Para" or block.t == "CodeBlock" or block.t == "Image" or block.t == "Plain" then
                table.insert(option, block)
            elseif block.t == "BlockQuote" then
                qHint = block
            end
        end

        -- first stem will be correct
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
    end

    utils.ShuffleInPlace(questionOptions)

    -- opening div
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

    table.insert(question, pandoc.RawBlock("html", [[</div>]])) -- closing div

    return pandoc.Div(question, { class = "qmulti__formated" })
end

function createQcheck(div)
    utils.writeEnvironments()

    local question = {}        

    local questionContent = {}
    local hint = nil
    local stems = nil

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
    -- gate name
    if div.attributes["gate"] ~= nil then
        gateName = div.attributes["gate"]
    end

    local correctAnswersCount = 0
    local wrongAnswerValue = 0    -- первое значения для неправильного ответа (увеличивается на -1000)
    local questionOptions = {}    -- список всех ответов
    for i, item in ipairs(stems.content) do
        local fullStem = {}       -- вариант ответа со всей разметко Alpinejs
        local option = {}
        local qHint = nil
        local qId = utils.RandomStringID(10) -- id для label

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
    utils.ShuffleInPlace(questionOptions)
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
                ✓ ]]..l10n("checkAnswer")..[[
            </button>
            ]]))

    table.insert(question, pandoc.RawBlock("html", [[</div>]])) -- закрывающий div

    return pandoc.Div(question, { class = "qcheck__formated" })
end

function createQsolution(div)
    utils.writeEnvironments()                   -- убеждаемся, что скрипты и стили добавлены в окружение
    local solution = {}                   -- итоговая разметка
    local solutionId = utils.RandomStringID(10) -- id для div c решением

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
                    💡 ]].. l10n("getAHint") ..[[
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
                    🗝️ ]]..l10n("solution")..[[
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
                ]].. l10n("nextStep") ..[[
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
            ">🗝️ ]]..l10n("showFullSolution")..[[</button>
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
        <span x-text="`]]..l10n("question")..[[ ${currentIndex + 1}/${totalSlides}`"></span>
    <button
        :class="isCurrentAnswerCorrect ? 'qgroup__pusle': ''"
        x-show="!isQuizFinished && (currentIndex + 1 < totalSlides)"
        x-transition
        :disabled="!isCurrentAnswerCorrect"
        x-on:click="next(); isCurrentAnswerCorrect = false"
    >
        ]] .. l10n("nextQuestion") .. [[ ▷
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
    utils.writeEnvironments()       -- убеждаемся, что скрипты и стили добавлены в окружение

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

function createQParson(div)
    utils.writeEnvironments()              -- убеждаемся, что скрипты и стили добавлены в окружение

    local taskID = utils.RandomStringID(7) -- уникальный идентификатор задания

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
    local languageClass = "markdown"
    if #solutionCode.classes > 0 then
        languageClass = solutionCode.classes[1]
    end

    local lines = {}
    local solutionJSstr = "[" -- строка с js массивом решения задачи
    for s in (solutionCode.text .. "\n"):gmatch(separator) do --"[^\r\n]+"
        local spCount = utils.count_leading_spaces(s)
        if spCount ~= #s then
            local ind = #lines + 1
            lines[ind] = s

            -- получаем разметку с подсветкой синтаксиса для строки кода
            local code_element = pandoc.Code(utils.trim_initial_spaces(s), { class = languageClass })
            local doc = pandoc.Pandoc({ pandoc.Plain({ code_element }) })
            local hl = utils.escapeHtmlDataAttribute(pandoc.write(doc, 'html'))

            solutionJSstr = solutionJSstr
                .. string.format("{id: %d, code: String.raw`%s`, hl: String.raw`%s`, indent: %d},",
                ind, utils.escapeHtmlDataAttribute(utils.trim_initial_spaces(s)), hl, spCount // spacesPerLevel)
        end
    end
    solutionJSstr = solutionJSstr .. "]"
    
    -- если есть дистракторы, добавляем их к блокам решения
    if distractors ~= nil then
        for s in (distractors.text .. "\n"):gmatch(separator) do --"[^\r\n]+"
            if utils.count_leading_spaces(s) ~= #s then
                table.insert(lines, s)
            end
        end
    end

    utils.ShuffleInPlace(lines) -- перемешиваем варианты ответов

    local sourceJSstr = "[" -- строка с js массивом вариантов, в том числе с дистракторами
    for ind, val in pairs(lines) do
        -- получаем разметку с подсветкой синтаксиса для строки кода
        local code_element = pandoc.Code(utils.trim_initial_spaces(val), { class = languageClass })
        local doc = pandoc.Pandoc({ pandoc.Plain({ code_element }) })
        local hl = utils.escapeHtmlDataAttribute(pandoc.write(doc, 'html'))
        
        sourceJSstr = sourceJSstr
            .. string.format("{id: %d, container: 'source', code: String.raw`%s`, hl: String.raw`%s`, indent: 0, error: false},",
            ind, utils.escapeHtmlDataAttribute(utils.trim_initial_spaces(val)), hl)
    end
    sourceJSstr = sourceJSstr .. "]"

    -- начало разметки компонента
    table.insert(elementContent, pandoc.RawBlock("html", [[
    <div
      x-data="{
        isAnswered: false,
        isShowFeedback: false,
        attempt: 0,
        maxHeight: 0,
        errorMessage: '', 
        source: ]]..sourceJSstr..[[,
        dest: [],
        solution: ]]..solutionJSstr..[[,
        maxIndent: 3, // максимальное количество отступов
        indentCh: ]]..spacesPerLevel..[[, // можно брать из атрибута фильтра

        onSortEnd(item, pos, toArray) {
            if(this.isShowFeedback) this.isShowFeedback = false;
            
            const fromArray = item.container === 'source' ? this.source : this.dest;
            

            const fromIndex = fromArray.findIndex(i => i.id === item.id);
            fromArray.splice(fromIndex, 1);
            toArray.splice(pos, 0, item);

            item.container = toArray === this.source ? 'source' : 'dest';

            // сбрасываем отступ, если строка возвращается в 'источник'
            if (toArray === this.source) {
                item.indent = 0;
                item.error = false;
            }
        },
        incIndent(line){
          if (this.isAnswered) return; // ответ правильный - отступы не меняем
          line.indent = Math.min(this.maxIndent, line.indent + 1);
          this.isShowFeedback = false;
        },
        decIndent(line){
          if (this.isAnswered) return; // ответ правильный - отступы не меняем
          line.indent = Math.max(0, line.indent - 1);
          this.isShowFeedback = false;
        },
        codeWrapperStyle(line){
            const colors = ['#fff0', '#60B99A', '#D3CE3D', '#F77825'];
            return `margin-left: ${this.indMarginString(line)}; border-left: 3px solid ${colors[line.indent]};`;
        },
        indMarginString(line){
          // значение отступа для margin-left у строки кода
          return `${line.indent * this.indentCh}ch`;
        },
        indentColorGenerator(indent){
          const colors = ['#fff0', '#60B99A', '#D3CE3D', '#F77825'];
          return colors[indent];
        },
        isErrorLabelVisible(line){
          return this.isShowFeedback && line.error;
        },
        feedback(){
          this.attempt++;
          this.isShowFeedback = true; // показать фидбек по вопросу

          const isSolutionLengthIncorrect = this.solution.length !== this.dest.length;
          if(isSolutionLengthIncorrect){
            this.errorMessage = ']]..l10n("incorrectNumberOfBlocks")..[[';
            return;
          }

          let isOrderOrIndentationIncorrect = false;
          this.dest.forEach((line, index) => {
            line.error = false;
            if (line.code !== this.solution[index].code || 
                line.indent !== this.solution[index].indent){
              isOrderOrIndentationIncorrect = true;
              line.error = true;
            }
          })

          if(isOrderOrIndentationIncorrect){
            this.errorMessage = ']]..l10n("incorrectOrderOfBlocks")..[[';
            return;
          }

          this.isShowFeedback = false; // показать фидбек по вопросу
          this.errorMessage = '';
          this.isAnswered = true;
        }
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
    "
    >
      <div
        x-show="isAnswered"
        x-transition=""
        class="qmulti__result__badge qmulti__result__correct"
        style="display: none"
      >
        <span>✔</span>
      </div>
]]))

    -- рендеринг условия задачи, если оно есть
    if #taskDescription ~= 0 then
        table.insert(elementContent, pandoc.Div(taskDescription, { class = "task__desc" }))
    end

    -- разметка для вариантов ответа и кнопок
    table.insert(elementContent, pandoc.RawBlock("html",[[
<!-- flex start -->
      <div class="block__container">
        <!-- Контейнер для вариантов ответа -->
        <div
          class="block-container source"
          :style="`height: ${maxHeight}px`"
          x-sort:config="{
            filter: ()=>{return isAnswered ? 'sort-item' : ''},
            swapThreshold: 0.5,
            invertSwap: true,
          }"
          x-sort:group="parson-]]..taskID..[["
          x-sort="(item, pos)=>{onSortEnd(item, pos, source)};"
        >
          <template x-for="line in source" :key="line.id">
            <div class="sort-item" x-sort:item="line">
              <button x-sort:ignore @click.stop="decIndent(line)">˂</button>
              <button x-sort:ignore @click.stop="incIndent(line)">˃</button>
              <div 
                class="code__wrapper"
                :style="codeWrapperStyle(line)">
                <code x-html="line.hl"></code>
              </div>
            </div>
          </template>
        </div>
        <!-- конец вариантов ответа  -->

        <!--контейнер для ответов  -->
        <div
          class="block-container solution"
          :style="`height: ${maxHeight}px`"
          x-sort:config="{
            filter: ()=>{return isAnswered ? 'sort-item' : ''},
            swapThreshold: 0.5,
            invertSwap: true,
          }"
          x-sort:group="parson-]]..taskID..[["
          x-sort="(item, pos)=>{onSortEnd(item, pos, dest)};"
        >
          <template x-for="line in dest" :key="line.id">
            <div
              :class="isErrorLabelVisible(line) ? 'error': '' "
              class="sort-item"
              x-sort:item="line"
            >
              <button x-sort:ignore @click.stop="decIndent(line)">˂</button>
              <button x-sort:ignore @click.stop="incIndent(line)">˃</button>
              <div 
                class="code__wrapper"
                :style="codeWrapperStyle(line)">
                <code x-html="line.hl"></code>
              </div>
            </div>
          </template>
        </div>
        <!-- конец контейнера для ответов -->
      </div>
      <!-- flex end -->

      <div class="header__buttons">
        <div x-show="isAnswered" x-transition="" style="display: none">
          <!-- временно убираем копирование в буфер обмена решения задачи
          <button
            class="copy_code"
            x-on:click="navigator.clipboard.writeText($refs.solutionPre.innerText)"
          >
            📋
          </button> 
          -->
          <span x-text="`Использовано попыток: ${attempt}`"
            >Использовано попыток: 0</span
          >
        </div>

        <button x-show="!isAnswered" x-on:click="feedback();">✓ ]]..l10n("checkAnswer")..[[</button>

        <div
          x-show="isShowFeedback === true"
          x-transition=""
          style="display: none"
        >
          <div
            x-transition=""
            x-show="!isAnswered"
            class="qmulti__wrong_result"
          >
            <span x-text="errorMessage">В коде есть ошибка.</span>
          </div>
        </div>
      </div>
    </div>
]]))

    -- готовый элемент
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
    utils.writeEnvironments()              -- убеждаемся, что скрипты и стили добавлены в окружение

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

function createQspot(div)
    utils.writeEnvironments() -- окружение
    local question = {}        -- разметка всего вопроса

    local qText = {} -- разметка для вещей, которые нужно найти на картинке

    local questionsContent = {}       -- список вопросов
    local containerMarkup = {}
    local markersMarkup = {}
    local mainImage = nil                 -- изображение
    local hint = nil           -- подсказка
    local markerIndex = 0 -- текущий индекс маркера


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
        elseif el.t == "Para" and el.content[1].t == "Span" and el.content[1].attr.attributes["pos"] then
            local pos = el.content[1].attr.attributes["pos"]

            table.insert(qText, pandoc.RawBlock("html",[[
            <span class="qspot_question">
                <span class="question__number">]]..(markerIndex + 1)..[[</span>
                <span class="question__text">]]..pandoc.utils.stringify(el.content)..[[</span>
            </span>
        ]]))

            -- разметка для маркера
            table.insert(containerMarkup, pandoc.RawBlock("html",
            [[<span class="marker" style="left: ]]..(markerIndex * 35)..[[px;" :class="getMarkerClass(]]..markerIndex..[[)">
            ]]..(markerIndex+1)..[[</span>]]))

            -- разметка для целевой области
            table.insert(containerMarkup, pandoc.RawBlock("html",
            [[<div class="qspot__area"]].. utils.css_style(pos) ..[[>]]..(markerIndex+1)..[[</div>]]))
            markerIndex = markerIndex + 1
        else
            table.insert(questionsContent, el)
        end
    end

    -- нет нужных элементов в разметке вопроса
    if #questionsContent == 0 or mainImage == nil then
        return pandoc.Div('')
    end

    -- начало основного блока
    table.insert(question, pandoc.RawBlock("html", [[
    <div class="qmulti" x-data="qspot" x-ref="container" :class="isAnswerCorrect && attempt === 1 && 'qmulti_first_try'"
    data-gate="]]..gateName..[["
    
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
    })"
    
    >
    <div x-show="isAnswerCorrect" x-transition="" class="qmulti__result__badge qmulti__result__correct">
        <span>✔</span>
    </div>
    ]]))

    table.insert(question, pandoc.Div(questionsContent));
    table.insert(question, pandoc.Div(qText, {class="qspot__questions_container"}))

    -- разметка с текстом подсказки, если она есть
    if hint ~= nil then
        table.insert(question, pandoc.RawBlock("html", [[<div x-show="isHintVisible" x-transition>]]))
        table.insert(question, pandoc.Div(hint))
        table.insert(question, pandoc.RawBlock("html", [[</div>]]))
        
        buttonsHtml =
        [[<button class="qmulti__hint_button"
        type="button"
        x-show="!isHintVisible && attempt >= 1 && !isAnswerCorrect" x-transition
        x-on:click="isHintVisible=!isHintVisible">
        ?
        </button>]]
        table.insert(question, pandoc.RawBlock("html", buttonsHtml))
    end

    table.insert(question, pandoc.RawBlock("html", [[<hr class="hr-text" data-content="?">
    <p class="qspot__instruction">]]..l10n("qSpotInstruction")..[[</p>
]]))

    -- table.insert(question, pandoc.Div(markersMarkup, {class="qspot__markers"}))
    table.insert(containerMarkup, mainImage)

    table.insert(question, pandoc.Div(containerMarkup, {class="qspot__container"}))

    table.insert(question, pandoc.RawBlock("html", [[
    <div>
            <button
                class="button__evaluate"
                x-show="!isAnswerCorrect"
                x-transition
                x-on:click="checkAnswer"
            >
                ✓ ]]..l10n("checkAnswer")..[[
            </button>
    </div>]]))

    table.insert(question, pandoc.RawBlock("html", [[</div>]])) -- конец основного блока

    return pandoc.Div(question, { class = "qspot__formated" })
end

local function render_elements(options)

    l10n.load(options.lang)

    return {
        Div = function(div)
            if quarto.doc.isFormat("html:js") then
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
            return nil
        end
    }

end

function Pandoc(doc)
  -- default options
  local options = {
    lang = pandoc.utils.stringify(doc.meta.lang)
  }

  -- replace default option with local 
  local globalOptions = doc.meta[EXTENSION_NAME]
  if type(globalOptions) == "table" then
    for k, v in pairs(globalOptions) do
      options[k] = pandoc.utils.stringify(v)
    end
  end

  return doc:walk(render_elements(options))
end