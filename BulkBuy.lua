local addonName, BulkBuy = ...
local frame = CreateFrame("Frame")

-- Function to create and show the dialog
local function ShowBulkBuyDialog(itemName, price, stackSize, numAvailable, index)
  if not BulkBuy.dialog then
    BulkBuy.dialog = CreateFrame("Frame", "BulkBuyDialog", UIParent, "BasicFrameTemplateWithInset")
    BulkBuy.dialog:SetSize(300, 160)
    BulkBuy.dialog:SetPoint("CENTER")
    BulkBuy.dialog:Hide()

    BulkBuy.dialog.title = BulkBuy.dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    BulkBuy.dialog.title:SetPoint("TOP", BulkBuy.dialog, "TOP", 0, -5)
    BulkBuy.dialog.title:SetText("Bulk Buy")

    BulkBuy.dialog.text = BulkBuy.dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    BulkBuy.dialog.text:SetPoint("TOP", BulkBuy.dialog, "TOP", 0, -35)
    BulkBuy.dialog.text:SetText("Enter quantity:")

    -- Qty input
    BulkBuy.dialog.editBox = CreateFrame("EditBox", nil, BulkBuy.dialog, "InputBoxTemplate")
    BulkBuy.dialog.editBox:SetSize(120, 30)
    BulkBuy.dialog.editBox:SetPoint("TOP", BulkBuy.dialog.text, "BOTTOM", 0, -5)
    BulkBuy.dialog.editBox:SetAutoFocus(true)
    BulkBuy.dialog.editBox:SetNumeric(true)

    -- Cost display
    BulkBuy.dialog.costText = BulkBuy.dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    BulkBuy.dialog.costText:SetPoint("TOP", BulkBuy.dialog.editBox, "BOTTOM", 0, -8)
    BulkBuy.dialog.costText:SetText("Cost: 0 gold")

    -- Update cost when the quantity changes
    BulkBuy.dialog.editBox:SetScript("OnTextChanged", function(self)
      local quantity = tonumber(self:GetText()) or 0
      local totalCost = quantity * price
      BulkBuy.dialog.costText:SetText("Cost: " .. GetCoinTextureString(totalCost)) -- Formats the cost with WoW coin icons
    end)

    -- Buy button
    BulkBuy.dialog.confirmButton = CreateFrame("Button", nil, BulkBuy.dialog, "UIPanelButtonTemplate")
    BulkBuy.dialog.confirmButton:SetSize(80, 22)
    BulkBuy.dialog.confirmButton:SetPoint("BOTTOM", BulkBuy.dialog, "BOTTOM", -50, 20)
    BulkBuy.dialog.confirmButton:SetText("Buy")
    BulkBuy.dialog.confirmButton:SetScript("OnClick", function()
      local quantity = tonumber(BulkBuy.dialog.editBox:GetText()) or 0
      BulkBuy:PurchaseItems(index, quantity, price, stackSize, numAvailable)
      BulkBuy.dialog:Hide()
    end)

    -- Cancel button
    BulkBuy.dialog.cancelButton = CreateFrame("Button", nil, BulkBuy.dialog, "UIPanelButtonTemplate")
    BulkBuy.dialog.cancelButton:SetSize(80, 22)
    BulkBuy.dialog.cancelButton:SetPoint("BOTTOM", BulkBuy.dialog, "BOTTOM", 50, 20)
    BulkBuy.dialog.cancelButton:SetText("Cancel")
    BulkBuy.dialog.cancelButton:SetScript("OnClick", function()
      BulkBuy.dialog:Hide()
    end)

    -- Capture Enter and Escape keys
    BulkBuy.dialog.editBox:SetScript("OnKeyDown", function(self, key)
      if key == "ENTER" then
        BulkBuy.dialog.confirmButton:Click()
      elseif key == "ESCAPE" then
        BulkBuy.dialog.cancelButton:Click()
      end
    end)

    -- Prevent keys from propagating to other frames
    BulkBuy.dialog:SetPropagateKeyboardInput(false)
  end

  BulkBuy.dialog.title:SetText("Bulk Buy: " .. itemName)
  BulkBuy.dialog:Show()
  BulkBuy.dialog.editBox:SetText("20")
  BulkBuy.dialog.editBox:HighlightText()
  BulkBuy.dialog.editBox:SetFocus()
end

-- Function to handle the bulk purchase
function BulkBuy:PurchaseItems(index, quantity, price, stackSize, numAvailable)
  if quantity <= 0 then
    print("|cffff0000Please enter a valid quantity.|r")
    return
  end

  local totalCost = quantity * price
  if totalCost > GetMoney() then
    print("|cffff0000You don't have enough gold to complete the order.|r")
    return
  end

  local freeBagSlots = 0
  for i = 0, 4 do
    local numberOfFreeSlots, _bagType = C_Container.GetContainerNumFreeSlots(i)
    freeBagSlots = freeBagSlots + numberOfFreeSlots
  end
  local requiredSlots = math.ceil(quantity / stackSize)
  if freeBagSlots < requiredSlots then
    print("|cffff0000You don't have enough bag space to complete the order.|r")
    return
  end

  -- Recursive function to mitigate "Item is busy" error
  local function BuyWithDelay(itemsLeft) 
    if itemsLeft > 0 then
      local buyAmount = math.min(stackSize, itemsLeft)
      BuyMerchantItem(index, buyAmount)
      itemsLeft = itemsLeft - buyAmount
      C_Timer.After(0.1, function() BuyWithDelay(itemsLeft) end)
    end
  end

  -- Start the buying process
  BuyWithDelay(quantity)

  print("|cff00ff00Successfully purchased " .. quantity .. " items!|r")
end

-- Override the default MerchantItemButton_OnModifiedClick function
function MerchantItemButton_OnModifiedClick(self, button)
  if button == "LeftButton" and IsShiftKeyDown() then
    local index = self:GetID()
    if MerchantFrame.selectedTab == 1 then     -- Merchant tab
      local itemName, _texture, price, _quantity, numAvailable, _isUsable, _extendedCost = GetMerchantItemInfo(index)
      local stackSize = GetMerchantItemMaxStack(index)
      if itemName then
        ShowBulkBuyDialog(itemName, price, stackSize, numAvailable, index)
        return         -- Prevent the default behavior
      end
    end
  end
  -- Call the original function for other cases
  if IsModifiedClick() then
    HandleModifiedItemClick(GetMerchantItemLink(self:GetID()))
  end
end
