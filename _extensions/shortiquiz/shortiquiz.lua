local function writeEnvironments()
  if quarto.doc.is_format("html:js") then
    quarto.doc.add_html_dependency({
      name = "alpine",
      version = "3.12",
      scripts = {
        { path = "alpine.min.js", afterBody = "true" } },
    })
    quarto.doc.add_html_dependency({
      name = "qstyles",
      version = "1",
      stylesheets = { "qstyles.css" }
    })
  end
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

local function ShuffleInPlace(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

return {
  ['qselect'] = function(args, kwargs, meta)
    -- TODO добавить выбор стиля: обычный текст или моноширный.
    writeEnvironments()
    local optionsStr = escapeHtmlDataAttribute(pandoc.utils.stringify(args[1]))

    local showText = escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["show"]))
    local mono = pandoc.utils.stringify(kwargs["mono"])
    local g = escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["gate"]))

    local delimiter = "|"
    local options = {}
    for match in string.gmatch(optionsStr, "([^" .. delimiter .. "]+)") do
      table.insert(options, match)
    end

    local correctAnswer = options[1]
    -- какой ответ показывать: из первого параметра или ключа show
    if showText == '' then
      showText = correctAnswer
    end
    -- quarto.log.output(correctAnswer)
    local html = [[
    <span x-data="{
      answer: '???',
      isCorrect: false,
      attempt: 0,
      correctAnswer: ']] .. correctAnswer .. [[',
      get answerVisibility() { return this.isCorrect },
      get questionVisibility() { return !this.isCorrect },
      get wrong() { return this.answer !== '???' && this.answer !== this.correctAnswer },
      isShakeHead: false,
      shake(){
          this.isShakeHead = true;
          setTimeout(() => {
            this.isShakeHead = false;
          }, 600);
      }
    }"
    data-gate=']] .. g .. [['
    x-init="$watch('answer', value => {
      isCorrect = answer === correctAnswer ? true : false;
      attempt++;
      if (!isCorrect) shake();
      $dispatch('answer-notification', {
        isCorrect: isCorrect,
        type: 'qselect',
        gate: ']] .. g .. [[',
        attempt: attempt
      })
    })">
    <span class="qinput__container" x-show="questionVisibility" x-transition>
      <select class="qselect__select"  x-model="answer">
        <option disabled>???</option>]]

    -- перемешиваем ответы, чтобы правильный ответ не всегда был первым в списке
    ShuffleInPlace(options)

    for _, option in ipairs(options) do
      html = html .. '<option>' .. option .. '</option>'
    end

    -- если выбран моноширный стиль ответа, оборачиваем его в тег <code>
    local answerFormated = showText
    if mono == "true" then
      answerFormated = [[<code>]] .. showText .. [[</code>]]
    end

    html = html .. [[
      </select>
      <span class="qinput__warning" x-show="wrong" x-transition x-cloak>
        <span :class="{ 'shake-head': isShakeHead }">x</span>
      </span>
      </span>
      <span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility"  x-transition.delay.200ms>]] ..
        answerFormated .. [[</span></span>]]

    return pandoc.RawBlock('html', html)
  end,
  ['qinput'] = function(args, kwargs, meta)
    writeEnvironments()
    local correctAnswer = escapeHtmlDataAttribute(args[1])
    local showText = escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["show"]))
    local hintsText = escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["hints"]))
    local size = pandoc.utils.stringify(kwargs["size"])
    local mono = pandoc.utils.stringify(kwargs["mono"])
    local tol = pandoc.utils.stringify(kwargs["tol"])
    local g = escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["gate"]))


    -- размер поля для ввода по умолчанию
    if size == '' then
      size = '2'
    end

    local tolHtml = nil
    if tol ~= nil and tol ~= "" then
      tolHtml = "tol:" .. tol .. ","
    else
      tolHtml = "tol: null,"
    end

    local html = [[
    <span x-data="{
      answer: '',
      isCorrect: false,
      ]] .. tolHtml ..
        [[
      correctAnswer: `]] .. correctAnswer .. [[`.split('|'),
      attempt: 0,
      get answerVisibility() { return this.isCorrect },
      get questionVisibility() { return !this.isCorrect },
      get wrong() { return this.answer !== '' && !this.setIsCorrect(this.answer) },
      get hints() { return this.wrong && this.attempt >= 3 },
      isShakeHead: false,
      shake(){
          this.isShakeHead = true;
          setTimeout(() => {
            this.isShakeHead = false;
          }, 600);
      },
      setIsCorrect(val){
        if (this.tol !== null){
          val = val.replace(',', '.');
          const a = Number(this.correctAnswer[0]);
          if (Number(val) <= a + this.tol && Number(val) >= a - this.tol){
            // ответ попадает в диапазон
            this.correctAnswer[0] = val; // введённый ответ выведем как правильный
            return true;
          }else{
            return false;
          }
        } else {
          // если не задана точность
          return this.correctAnswer.includes(val);
        }
      }
    }"
    data-gate=']] .. g .. [['
    x-init="$watch('answer', value => {
      isCorrect = setIsCorrect(answer);
      if (!isCorrect) shake();
      $dispatch('answer-notification', {
        isCorrect: isCorrect,
        type: 'qinput',
        gate: ']] .. g .. [[',
        attempt: attempt
      })
    })"
    >
    <span class="qinput__container" x-show="questionVisibility" x-transition>
      <input type="text" size="]] .. size .. [["   x-model.lazy="answer" placeholder="???" x-on:change="attempt++"/>
      <span class="qinput__warning" x-show="wrong" x-cloak x-transition> <span :class="{ 'shake-head': isShakeHead }">x</span> </span>]]

    if hintsText ~= '' then
      html = html ..
          [[<span x-show="hints" data-hint="]] .. hintsText .. [[" class="qinput__tooltip" x-transition x-cloak>
      <span class="pulse" x-clock> ? </span>
      </span>]]
    end


    html = html .. [[</span>]]
    -- какой ответ показывать: из первого параметра или ключа show
    if showText == '' then
      if mono == "true" then
        html = html ..
            [[<span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility" x-transition.delay.200ms x-cloak>
            <code x-text="correctAnswer[0]"></code>
          </span>]]
      else
        html = html ..
            [[<span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility" x-text="correctAnswer[0]" x-cloak x-transition.delay.200ms></span>]]
      end
    else
      if mono == "true" then
        html = html ..
            [[<span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility" x-cloak x-transition.delay.200ms>
            <code>]] .. showText .. [[</code></span>]]
      else
        html = html ..
            [[<span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility" x-cloak  x-transition.delay.200ms>]] ..
            showText .. [[</span>]]
      end
    end

    html = html .. [[</span>]]

    return pandoc.RawBlock('html', html)
  end,
  ['qnext'] = function(args, kwargs, meta)
    writeEnvironments()
    local g = escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["gate"]))
    local html = [[
    <div class="qnext__container">
    <button
      x-data="{
        isVisible: true
      }"
      x-show="isVisible"
      x-cloak
      x-transition
      data-gate=']] .. g .. [['
      x-on:click="
      isVisible = !isVisible;
      $dispatch('answer-notification', {
        isCorrect: true,
        type: 'qnext',
        gate: ']] .. g .. [[',
        attempt: 1
      });
      "
    >
    Далее
    </button>
    </div>]]
    return pandoc.RawBlock('html', html)
  end
}
