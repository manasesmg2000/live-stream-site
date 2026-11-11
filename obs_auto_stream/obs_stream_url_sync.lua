--[[
  =============================================================================
  Script Lua para OBS Studio — Iglesia Evangélica Pan Bendito
  Escribe automáticamente la URL del directo al pulsar "Iniciar transmisión"
  y vacía el archivo al pulsar "Detener transmisión".
  =============================================================================
--]]

local obs = obslua
local file_path = ""
local live_url = ""

function write_file(content)
    if file_path == nil or file_path == "" then
        return
    end
    local file = io.open(file_path, "w")
    if file then
        file:write(content)
        file:close()
        obs.script_log(obs.LOG_INFO, "[Pan Bendito] Archivo actualizado: " .. content)
    else
        obs.script_log(obs.LOG_WARNING, "[Pan Bendito] No se pudo abrir el archivo para escribir: " .. file_path)
    end
end

function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
        obs.script_log(obs.LOG_INFO, "[Pan Bendito] Emisión iniciada en OBS.")
        write_file(live_url)
    elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
        obs.script_log(obs.LOG_INFO, "[Pan Bendito] Emisión detenida en OBS. Vaciando archivo.")
        write_file("")
    end
end

function script_description()
    return "Sincronizador Automático de Directo para la Iglesia Evangélica Pan Bendito.\n\n" ..
           "Escribe la URL del directo en un archivo al empezar a emitir y la borra al terminar, " ..
           "activando y desactivando automáticamente la emisión en la App móvil y en la Web."
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_path(props, "file_path", "Ruta del archivo a escribir (ej: directo_obs.txt):", obs.OBS_PATH_FILE, "Archivos de texto (*.txt)", nil)
    obs.obs_properties_add_text(props, "live_url", "URL de YouTube del directo:", obs.OBS_TEXT_DEFAULT)
    return props
end

function script_update(settings)
    file_path = obs.obs_data_get_string(settings, "file_path")
    live_url = obs.obs_data_get_string(settings, "live_url")
end

function script_load(settings)
    obs.obs_frontend_add_event_callback(on_event)
end

function script_unload()
    -- Nada pendiente
end
