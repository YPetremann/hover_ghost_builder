local transfer = require("modules.transfer")

--- Validate that in_inventory contains usable entries
local function has_valid_inventory_entries(inventory_list, proxy_target)
  if not inventory_list or type(inventory_list) ~= "table" then return false end
  for _, entry in ipairs(inventory_list) do
    if entry and type(entry.stack) == "number" and type(entry.inventory) == "number" then
      local inv = proxy_target.get_inventory(entry.inventory)
      if inv and inv.valid and entry.stack + 1 <= #inv and inv[entry.stack + 1].valid_for_read then
        return true
      end
    end
  end
  return false
end

---complete a request proxy
---@param player LuaPlayer
---@param proxy LuaEntity
local function fill_request_proxy(player, proxy)
  local playerInv = { player.get_inventory(defines.inventory.character_main), player.cursor_stack }
  local removal_plan = proxy.removal_plan or {}
  local insert_plan = proxy.insert_plan or {}
  local new_removal_plan = {}
  local new_insert_plan = {}
  local changed_removal_plan = false
  local changed_insert_plan = false

  for _, plan in ipairs(removal_plan) do
    if plan and plan.items and has_valid_inventory_entries(plan.items.in_inventory, proxy.proxy_target) then
      for _, from in ipairs(plan.items.in_inventory) do
        if from and from.count and from.count > 0 then
          local inv = proxy.proxy_target.get_inventory(from.inventory)
          if inv and inv.valid and from.stack + 1 <= #inv then
            local stack = inv[from.stack + 1]
            if stack and stack.valid_for_read then
              local transfer_stack = { name = plan.id.name, quality = plan.id.quality or "normal", count = from.count }
              local sourceInv = { stack }
              local diff = transfer.transfer_stack(transfer_stack, sourceInv, playerInv, true)
              if diff and diff > 0 then
                from.count = from.count - diff
                changed_removal_plan = true
              end
            end
          end
        end
      end
      if has_valid_inventory_entries(plan.items.in_inventory, proxy.proxy_target) then
        table.insert(new_removal_plan, plan)
      end
    end
  end

  for _, plan in ipairs(insert_plan) do
    if plan and plan.items and has_valid_inventory_entries(plan.items.in_inventory, proxy.proxy_target) then
      for _, to in ipairs(plan.items.in_inventory) do
        if to and to.count and to.count > 0 then
          local inv = proxy.proxy_target.get_inventory(to.inventory)
          if inv and inv.valid and to.stack + 1 <= #inv then
            local stack = inv[to.stack + 1]
            if stack then
              local transfer_stack = { name = plan.id.name, quality = plan.id.quality or "normal", count = to.count }
              local targetInv = { stack }
              local diff = transfer.transfer_stack(transfer_stack, playerInv, targetInv, true)
              if diff and diff > 0 then
                to.count = to.count - diff
                changed_insert_plan = true
              end
            end
          end
        end
      end
      if has_valid_inventory_entries(plan.items.in_inventory, proxy.proxy_target) then
        table.insert(new_insert_plan, plan)
      end
    end
  end

  if changed_removal_plan then
    proxy.removal_plan = new_removal_plan
  end
  if changed_insert_plan then
    proxy.insert_plan = new_insert_plan
  end

  local request_count = 0
  for _, plan in ipairs(proxy.removal_plan or {}) do
    if plan and plan.items then request_count = request_count + 1 end
  end
  for _, plan in ipairs(proxy.insert_plan or {}) do
    if plan and plan.items then request_count = request_count + 1 end
  end
  if request_count == 0 then
    proxy.destroy()
  end

  return changed_removal_plan or changed_insert_plan
end

--- complete all request proxies of an entity
--- @param player LuaPlayer
--- @param hovered_entity LuaEntity
return function(player, hovered_entity)
  local entities = player.surface.find_entities_filtered({
    name = "item-request-proxy",
    position = hovered_entity.position,
  })
  local has_filled = false
  for _, proxy in ipairs(entities) do
    if fill_request_proxy(player, proxy) then has_filled = true end
  end
  return has_filled
end
