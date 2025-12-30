R("99")

function fizz_buzz(count)
    local result = {}
    for i = 1, count do
        if i % 15 == 0 then
            vim.list_extend(result, { "FizzBuzz" })
        elseif i % 3 == 0 then
            vim.list_extend(result, { "Fizz" })
        elseif i % 5 == 0 then
            vim.list_extend(result, { "Buzz" })
        else
            vim.list_extend(result, { tostring(i) })
        end
    end
    return result
end

--- @param numbers number[]
function sort(numbers)
    table.sort(numbers)
    return numbers
end
