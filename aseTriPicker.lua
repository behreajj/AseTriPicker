local defaults <const> = {
    wCanvas = 200,
    hCanvas = 200,
    xCenter = 100,
    yCenter = 100,
    ringInEdge = 0.9,
    angOffset = 0.5235987755983,
    hue = 0.0,
    sat = 1.0,
    val = 1.0,
    alpha = 1.0,
    retEps = 0.015,
    textDisplayLimit = 50,
    swatchSize = 16,
    lrKeyIncr = 1.0 / 1080.0
}

local active <const> = {
    wCanvas = defaults.wCanvas,
    hCanvas = defaults.hCanvas,

    hueFore = defaults.hue,
    satFore = defaults.sat,
    valFore = defaults.val,
    alphaFore = defaults.alpha,

    hueBack = defaults.hue,
    satBack = defaults.sat,
    valBack = defaults.val,
    alphaBack = defaults.alpha,

    fgBgFlag = 0,
    mouseDownRing = false,
    mouseDownTri = false,
}

---@param h number
---@param s number
---@param v number
---@return number r
---@return number g
---@return number b
local function hsvToRgb(h, s, v)
    local h6 <const> = h * 6.0

    local sector <const> = math.floor(h6)
    local tint1 <const> = v * (1.0 - s)
    local tint2 <const> = v * (1.0 - s * (h6 - sector))
    local tint3 <const> = v * (1.0 - s * (1.0 + sector - h6))

    if sector == 0 then
        return v, tint3, tint1
    elseif sector == 1 then
        return tint2, v, tint1
    elseif sector == 2 then
        return tint1, v, tint3
    elseif sector == 3 then
        return tint1, tint2, v
    elseif sector == 4 then
        return tint3, tint1, v
    elseif sector == 5 then
        return v, tint1, tint2
    end

    return 0.0, 0.0, 0.0
end

---@param r number
---@param g number
---@param b number
---@return number h
---@return number s
---@return number v
local function rgbToHsv(r, g, b)
    local gbmx <const> = math.max(g, b)
    local gbmn <const> = math.min(g, b)
    local mx <const> = math.max(r, gbmx)

    if mx <= 0.0 then return 0.0, 0.0, 0.0 end

    local mn <const> = math.min(r, gbmn)
    local diff <const> = mx - mn

    if diff <= 0.0 then
        local light <const> = (mx + mn) * 0.5
        if light >= 1.0 then
            return 0.0, 0.0, 1.0
        end
        return 0.0, 0.0, mx
    end

    local hue = 0.0
    if r == mx then
        hue = (g - b) / diff
        if g < b then hue = hue + 6.0 end
    elseif g == mx then
        hue = 2.0 + (b - r) / diff
    elseif b == mx then
        hue = 4.0 + (r - g) / diff
    end

    return hue / 6.0, diff / mx, mx
end

local initFgColor <const> = Color(app.fgColor)
active.hueFore, active.satFore, active.valFore = rgbToHsv(
    initFgColor.red / 255.0,
    initFgColor.green / 255.0,
    initFgColor.blue / 255.0)
active.alphaFore = initFgColor.alpha / 255.0

local initBgColor <const> = Color(app.bgColor)
active.hueBack, active.satBack, active.valBack = rgbToHsv(
    initBgColor.red / 255.0,
    initBgColor.green / 255.0,
    initBgColor.blue / 255.0)
active.alphaBack = initBgColor.alpha / 255.0

local dlg = Dialog { title = "Color Picker" }

dlg:canvas {
    id = "triCanvas",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvas,
    onkeydown = function(event)
        if event.code == "ArrowRight" then
            if event.shiftKey then
                active.fgBgFlag = 1
                active.hueBack = (active.hueBack + defaults.lrKeyIncr) % 1.0
                app.command.SwitchColors()
                app.fgColor = Color {
                    hue = active.hueBack * 360.0,
                    saturation = active.satBack,
                    value = active.valBack,
                    alpha = math.floor(active.alphaBack * 255.0 + 0.5)
                }
                app.command.SwitchColors()
            else
                active.fgBgFlag = 0
                active.hueFore = (active.hueFore + defaults.lrKeyIncr) % 1.0
                app.fgColor = Color {
                    hue = active.hueFore * 360.0,
                    saturation = active.satFore,
                    value = active.valFore,
                    alpha = math.floor(active.alphaFore * 255.0 + 0.5)
                }
            end
            dlg:repaint()
        elseif event.code == "ArrowLeft" then
            if event.shiftKey then
                active.fgBgFlag = 1
                active.hueBack = (active.hueBack - defaults.lrKeyIncr) % 1.0
                app.command.SwitchColors()
                app.fgColor = Color {
                    hue = active.hueBack * 360.0,
                    saturation = active.satBack,
                    value = active.valBack,
                    alpha = math.floor(active.alphaBack * 255.0 + 0.5)
                }
                app.command.SwitchColors()
            else
                active.fgBgFlag = 0
                active.hueFore = (active.hueFore - defaults.lrKeyIncr) % 1.0
                app.fgColor = Color {
                    hue = active.hueFore * 360.0,
                    saturation = active.satFore,
                    value = active.valFore,
                    alpha = math.floor(active.alphaFore * 255.0 + 0.5)
                }
            end
            dlg:repaint()
        elseif event.shiftKey and event.code == "KeyX" then
            local hTemp <const> = active.hueBack
            local sTemp <const> = active.satBack
            local vTemp <const> = active.valBack
            local aTemp <const> = active.alphaBack

            active.hueBack = active.hueFore
            active.satBack = active.satFore
            active.valBack = active.valFore
            active.alphaBack = active.alphaFore

            active.hueFore = hTemp
            active.satFore = sTemp
            active.valFore = vTemp
            active.alphaFo = aTemp

            dlg:repaint()
        end
    end,
    onmousedown = function(event)
        local ringInEdge <const> = defaults.ringInEdge
        local sqRie <const> = ringInEdge * ringInEdge

        local wCanvas <const> = active.wCanvas
        local hCanvas <const> = active.hCanvas
        local xCenter <const> = wCanvas * 0.5
        local yCenter <const> = hCanvas * 0.5
        local shortEdge <const> = math.min(wCanvas, hCanvas)
        local rCanvas <const> = (shortEdge - 1.0) * 0.5
        local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

        local xMouseDown <const> = event.x
        local yMouseDown <const> = event.y
        local xDelta <const> = xMouseDown - xCenter
        local yDelta <const> = yCenter - yMouseDown

        local xNorm <const> = xDelta * rCanvasInv
        local yNorm <const> = yDelta * rCanvasInv

        local sqMag <const> = xNorm * xNorm + yNorm * yNorm
        if sqMag >= sqRie and sqMag <= 1.0 then
            active.mouseDownRing = true
            if event.button == MouseButton.RIGHT then
                active.fgBgFlag = 1
            end
        elseif sqMag < sqRie then
            active.mouseDownTri = true
            if event.button == MouseButton.RIGHT then
                active.fgBgFlag = 1
            end
        end
    end,
    onmouseup = function(event)
        active.mouseDownRing = false
        active.mouseDownTri = false
        active.fgBgFlag = 0
    end,
    onmousemove = function(event)
        if active.mouseDownRing or active.mouseDownTri then
            local wCanvas <const> = active.wCanvas
            local hCanvas <const> = active.hCanvas
            local xCenter <const> = wCanvas * 0.5
            local yCenter <const> = hCanvas * 0.5
            local shortEdge <const> = math.min(wCanvas, hCanvas)
            local rCanvas <const> = (shortEdge - 1.0) * 0.5
            local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

            local xMouseMove <const> = event.x
            local yMouseMove <const> = event.y
            local xDelta <const> = xMouseMove - xCenter
            local yDelta <const> = yCenter - yMouseMove

            local xNorm <const> = xDelta * rCanvasInv
            local yNorm <const> = yDelta * rCanvasInv

            if active.mouseDownRing then
                local angOffset <const> = defaults.angOffset
                local tau <const> = 6.2831853071796
                local angSigned <const> = angOffset + math.atan(yNorm, xNorm)
                local hueWheel <const> = angSigned / tau
                if active.fgBgFlag == 1 then
                    active.hueBack = hueWheel % 1.0
                    app.command.SwitchColors()
                    app.fgColor = Color {
                        hue = active.hueBack * 360.0,
                        saturation = active.satBack,
                        value = active.valBack,
                        alpha = math.floor(active.alphaBack * 255.0 + 0.5)
                    }
                    app.command.SwitchColors()
                else
                    active.hueFore = hueWheel % 1.0
                    app.fgColor = Color {
                        hue = active.hueFore * 360.0,
                        saturation = active.satFore,
                        value = active.valFore,
                        alpha = math.floor(active.alphaFore * 255.0 + 0.5)
                    }
                end
                dlg:repaint()
            elseif active.mouseDownTri then
                local ringInEdge <const> = defaults.ringInEdge
                local angOffset <const> = defaults.angOffset
                local tau <const> = 6.2831853071796
                local sqrt3_2 <const> = 0.86602540378444

                local hActive = 0.0
                if active.fgBgFlag == 1 then
                    hActive = active.hueBack
                else
                    hActive = active.hueFore
                end

                -- Find main point of the triangle.
                local hActiveTheta <const> = (hActive * tau) - angOffset
                local xTri1 <const> = ringInEdge * math.cos(hActiveTheta)
                local yTri1 <const> = ringInEdge * math.sin(hActiveTheta)

                -- Find the other two triangle points, 120 degrees away.
                local rt32x <const> = sqrt3_2 * xTri1
                local rt32y <const> = sqrt3_2 * yTri1
                local halfx <const> = -0.5 * xTri1
                local halfy <const> = -0.5 * yTri1

                local xTri2 <const> = halfx - rt32y
                local yTri2 <const> = halfy + rt32x

                local xTri3 <const> = halfx + rt32y
                local yTri3 <const> = halfy - rt32x

                -- For calculation of barycentric coordinates.
                local yDiff2_3 <const> = yTri2 - yTri3
                local xDiff1_3 <const> = xTri1 - xTri3
                local xDiff3_2 <const> = xTri3 - xTri2
                local yDiff1_3 <const> = yTri1 - yTri3
                local yDiff3_1 <const> = yTri3 - yTri1
                local bwDenom <const> = yDiff2_3 * xDiff1_3 + xDiff3_2 * yDiff1_3
                local bwDnmInv <const> = 1.0 / bwDenom

                local xbw <const> = xNorm - xTri3
                local ybw <const> = yNorm - yTri3
                local w1 <const> = math.min(math.max(
                    (yDiff2_3 * xbw + xDiff3_2 * ybw) * bwDnmInv,
                    0.0), 1.0)
                local w2 <const> = math.min(math.max(
                    (yDiff3_1 * xbw + xDiff1_3 * ybw) * bwDnmInv,
                    0.0), 1.0)
                local w3 <const> = math.min(math.max(
                    1.0 - w1 - w2,
                    0.0), 1.0)

                local wSum <const> = w1 + w2 + w3
                local wSumInv <const> = wSum ~= 0.0 and 1.0 / wSum or 0.0
                -- w2 is white, w3 is black.
                -- Black saturation is undefined in HSV.
                local s <const> = (w1 + w3) * wSumInv
                local v <const> = (w1 + w2) * wSumInv
                local a8 <const> = math.floor(active.alphaBack * 255.0 + 0.5)

                local diagSq <const> = v * v + s * s
                local coeff <const> = diagSq < 0.0 and 0.0 or w2
                local rBase <const>, gBase <const>, bBase <const> = hsvToRgb(hActive, 1.0, 1.0)

                local rf <const> = (w1 * rBase + coeff) * wSumInv
                local gf <const> = (w1 * gBase + coeff) * wSumInv
                local bf <const> = (w1 * bBase + coeff) * wSumInv

                local r8 <const> = math.floor(rf * 255.0 + 0.5)
                local g8 <const> = math.floor(gf * 255.0 + 0.5)
                local b8 <const> = math.floor(bf * 255.0 + 0.5)

                if active.fgBgFlag == 1 then
                    active.satBack = s
                    active.valBack = v
                    app.command.SwitchColors()
                    app.fgColor = Color { r = r8, g = g8, b = b8, a = a8 }
                    app.command.SwitchColors()
                else
                    active.satFore = s
                    active.valFore = v
                    app.fgColor = Color { r = r8, g = g8, b = b8, a = a8 }
                end

                dlg:repaint()
            end
        end
    end,
    onpaint = function(event)
        local ringInEdge <const> = defaults.ringInEdge
        local sqRie <const> = ringInEdge * ringInEdge
        local angOffset <const> = defaults.angOffset
        local retEps <const> = defaults.retEps
        local tau <const> = 6.2831853071796
        local sqrt3_2 <const> = 0.86602540378444

        local ctx <const> = event.context
        ctx.antialias = true

        local wCanvas <const> = ctx.width
        local hCanvas <const> = ctx.height
        if wCanvas <= 1 or hCanvas <= 1 then return end

        local xCenter <const> = wCanvas * 0.5
        local yCenter <const> = hCanvas * 0.5
        local shortEdge <const> = math.min(wCanvas, hCanvas)
        local rCanvas <const> = (shortEdge - 1.0) * 0.5
        local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

        active.wCanvas = wCanvas
        active.hCanvas = hCanvas

        local hActive = 0
        local sActive = 0
        local vActive = 0
        if active.fgBgFlag == 1 then
            hActive = active.hueBack
            sActive = active.satBack
            vActive = active.valBack
        else
            hActive = active.hueFore
            sActive = active.satFore
            vActive = active.valFore
        end

        -- Find main point of the triangle.
        local hActiveTheta <const> = (hActive * tau) - angOffset
        local xTri1 <const> = ringInEdge * math.cos(hActiveTheta)
        local yTri1 <const> = ringInEdge * math.sin(hActiveTheta)

        -- Find the other two triangle points, 120 degrees away.
        local rt32x <const> = sqrt3_2 * xTri1
        local rt32y <const> = sqrt3_2 * yTri1
        local halfx <const> = -0.5 * xTri1
        local halfy <const> = -0.5 * yTri1

        local xTri2 <const> = halfx - rt32y
        local yTri2 <const> = halfy + rt32x

        local xTri3 <const> = halfx + rt32y
        local yTri3 <const> = halfy - rt32x

        -- For calculation of barycentric coordinates.
        -- Cf. https://codeplea.com/triangular-interpolation
        local yDiff2_3 <const> = yTri2 - yTri3
        local xDiff1_3 <const> = xTri1 - xTri3
        local xDiff3_2 <const> = xTri3 - xTri2
        local yDiff1_3 <const> = yTri1 - yTri3
        local yDiff3_1 <const> = yTri3 - yTri1
        local bwDenom <const> = yDiff2_3 * xDiff1_3 + xDiff3_2 * yDiff1_3
        local bwDnmInv <const> = 1.0 / bwDenom
        local rBase <const>, gBase <const>, bBase <const> = hsvToRgb(hActive, 1.0, 1.0)

        local strpack <const> = string.pack
        local floor <const> = math.floor
        local atan <const> = math.atan
        local abs <const> = math.abs

        ---@type string[]
        local byteStrs <const> = {}
        local packZero <const> = strpack("B B B B", 0, 0, 0, 0)
        local lenCanvas <const> = wCanvas * hCanvas
        local i = 0
        while i < lenCanvas do
            local xCanvas <const> = i % wCanvas
            local yCanvas <const> = i // wCanvas

            local xDelta <const> = xCanvas - xCenter
            local yDelta <const> = yCenter - yCanvas

            local xNorm <const> = xDelta * rCanvasInv
            local yNorm <const> = yDelta * rCanvasInv

            local sqMag <const> = xNorm * xNorm + yNorm * yNorm

            local byteStr = packZero
            if sqMag >= sqRie and sqMag <= 1.0 then
                -- Within the rim of the hue circle.
                local angSigned <const> = angOffset + atan(yNorm, xNorm)
                local hueWheel <const> = (angSigned % tau) / tau

                local rf <const>, gf <const>, bf <const> = hsvToRgb(hueWheel, 1.0, 1.0)
                local r8 <const> = floor(rf * 255.0 + 0.5)
                local g8 <const> = floor(gf * 255.0 + 0.5)
                local b8 <const> = floor(bf * 255.0 + 0.5)

                byteStr = strpack("B B B B", r8, g8, b8, 255)
            elseif sqMag < sqRie then
                -- Inscribed triangle.
                local xbw <const> = xNorm - xTri3
                local ybw <const> = yNorm - yTri3
                local w1 <const> = (yDiff2_3 * xbw + xDiff3_2 * ybw) * bwDnmInv
                local w2 <const> = (yDiff3_1 * xbw + xDiff1_3 * ybw) * bwDnmInv
                local w3 <const> = 1.0 - w1 - w2

                if w1 >= 0.0 and w1 <= 1.0
                    and w2 >= 0.0 and w2 <= 1.0
                    and w3 >= 0.0 and w3 <= 1.0 then
                    local wSum <const> = w1 + w2 + w3
                    local wSumInv <const> = wSum ~= 0.0 and 1.0 / wSum or 0.0
                    -- w2 is white, w3 is black.
                    -- Black saturation is undefined in HSV.
                    local s <const> = (w1 + w3) * wSumInv
                    local v <const> = (w1 + w2) * wSumInv

                    local diagSq <const> = v * v + s * s
                    local coeff <const> = diagSq < 0.0 and 0.0 or w2

                    local rf <const> = (w1 * rBase + coeff) * wSumInv
                    local gf <const> = (w1 * gBase + coeff) * wSumInv
                    local bf <const> = (w1 * bBase + coeff) * wSumInv

                    local r8 = floor(rf * 255 + 0.5)
                    local g8 = floor(gf * 255 + 0.5)
                    local b8 = floor(bf * 255 + 0.5)

                    byteStr = strpack("B B B B", r8, g8, b8, 255)
                end
            end

            i = i + 1
            byteStrs[i] = byteStr
        end

        -- Draw picker canvas.
        local imgSpec <const> = ImageSpec {
            width = wCanvas,
            height = hCanvas,
            transparentColor = 0,
            colorMode = ColorMode.RGB
        }
        local img <const> = Image(imgSpec)
        img.bytes = table.concat(byteStrs)
        ctx:drawImage(img,
            Rectangle(0, 0, wCanvas, hCanvas),
            Rectangle(0, 0, wCanvas, hCanvas))

        local swatchSize <const> = defaults.swatchSize
        local offset <const> = swatchSize // 2

        -- Draw background color swatch.
        local backColor <const> = Color {
            hue = active.hueBack * 360,
            saturation = active.satBack,
            value = active.valBack,
            alpha = 255
        }
        ctx.color = backColor
        ctx:fillRect(Rectangle(
            offset, hCanvas - swatchSize - 1,
            swatchSize, swatchSize))

        -- Draw foreground color swatch.
        local foreColor <const> = Color {
            hue = active.hueFore * 360,
            saturation = active.satFore,
            value = active.valFore,
            alpha = 255
        }
        ctx.color = foreColor
        ctx:fillRect(Rectangle(
            0, hCanvas - swatchSize - 1 - offset,
            swatchSize, swatchSize))

        -- If dialog is wide enough, draw diagnostic text.
        if (wCanvas - hCanvas) > defaults.textDisplayLimit
            and rCanvas > swatchSize * 2 then
            local textSize <const> = ctx:measureText("E")
            local yIncr <const> = textSize.height + 4

            ctx.color = app.theme.color.text
            if sActive > 0.0 and vActive > 0.0 then
                ctx:fillText(string.format(
                    "H: %.2f", hActive * 360), 2, 2 + yIncr * 0)
            else
                ctx:fillText("H: ---", 2, 2 + yIncr * 0)
            end
            ctx:fillText(string.format(
                "S: %.2f%%", sActive * 100), 2, 2 + yIncr * 1)
            ctx:fillText(string.format(
                "V: %.2f%%", vActive * 100), 2, 2 + yIncr * 2)

            local rf <const>, gf <const>, bf <const> = hsvToRgb(
                hActive, sActive, vActive)

            ctx:fillText(string.format(
                "R: %.2f%%", rf * 100), 2, 2 + yIncr * 4)
            ctx:fillText(string.format(
                "G: %.2f%%", gf * 100), 2, 2 + yIncr * 5)
            ctx:fillText(string.format(
                "B: %.2f%%", bf * 100), 2, 2 + yIncr * 6)

            local r8 <const> = floor(rf * 255 + 0.5)
            local g8 <const> = floor(gf * 255 + 0.5)
            local b8 <const> = floor(bf * 255 + 0.5)

            ctx:fillText(string.format(
                "#%06x", r8 << 0x10|g8 << 0x08|b8), 2, 2 + yIncr * 8)
        end
    end,
}

dlg:button {
    id = "getForeButton",
    text = "&FORE",
    onclick = function()
        local fgColor <const> = app.fgColor
        local r8 <const> = fgColor.red
        local g8 <const> = fgColor.green
        local b8 <const> = fgColor.blue
        local t8 <const> = fgColor.alpha
        active.hueFore, active.satFore, active.valFore = rgbToHsv(
            r8 / 255.0, g8 / 255.0, b8 / 255.0)
        active.alphaFore = t8 / 255.0
        dlg:repaint()
    end
}

dlg:button {
    id = "getForeButton",
    text = "&BACK",
    onclick = function()
        app.command.SwitchColors()
        local bgColor <const> = app.fgColor
        local r8 <const> = bgColor.red
        local g8 <const> = bgColor.green
        local b8 <const> = bgColor.blue
        local t8 <const> = bgColor.alpha
        app.command.SwitchColors()
        active.hueBack, active.satBack, active.valBack = rgbToHsv(
            r8 / 255.0, g8 / 255.0, b8 / 255.0)
        active.alphaBack = t8 / 255.0
        dlg:repaint()
    end
}

dlg:button {
    id = "exitButton",
    text = "&X",
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}