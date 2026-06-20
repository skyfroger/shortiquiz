
-- // LOCALIZATIONS STRINGS //
local loc_data = {
  en = {
    inputPlaceholder = "Input Your Answer",
    checkAnswer = "Check",
    incorrectNumberOfBlocks = "Incorrect Number of Blocks in the Solution",
    incorrectOrderOfBlocks = "Incorrect Order of Blocks or Indentation Errors",
    nextQuestion = "Next Question",
    question = "Question",
    getAHint = "Get a Hint",
    solution = "Solution",
    nextStep = "Next Step",
    showFullSolution = "Show Full Solution",
    qSpotInstruction = "Click on the image to select the correct spot"
  },
  ru = {
    inputPlaceholder = "Введите ответ",
    checkAnswer = "Проверить",
    incorrectNumberOfBlocks = "В решении неправильное количество блоков",
    incorrectOrderOfBlocks = "Неправильный порядок блоков или ошибки в отступах",
    nextQuestion = "Следующий вопрос",
    question = "Вопрос",
    getAHint = "Получить подсказку",
    solution = "Получить решение",
    nextStep = "Следующий шаг",
    showFullSolution = "Показать всё решение",
    qSpotInstruction = "Кликните по изображению чтобы выбрать ответ"
  }
}
-- // END OF LOCALIZATION STRINGS //

-- localisation helper function
local M = {}
local current_loc_data = loc_data["en"] -- default language: english

-- set localisation language
function M.load(lang)
  current_loc_data = loc_data[lang] or loc_data["en"]
end

function M.get(key)
  return current_loc_data[key] or loc_data["en"][key] or key
end

-- make table callable
setmetatable(M, {
  __call = function(_, key)
    return M.get(key)
  end
})

return M