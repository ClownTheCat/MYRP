MYRP TEST BOTS v1.1
===================

Установка
---------
1. Распакуйте папку myrp_testbots в:
   garrysmod/gamemodes/myrp/schema/plugins/
2. Замените файл sv_matchhud.lua из архива по пути:
   garrysmod/gamemodes/myrp/schema/plugins/myrp_matchflow/sv_matchhud.lua
3. Полностью перезапустите сервер.

В архиве уже находится исправленный sv_matchhud.lua. В нём сохранена исходная
логика подсчёта убийств, но добавлено распознавание тестовых ботов по метке
ixMYRPTestBotFaction. Обычные игроки по-прежнему определяются через Helix.

Команды сервера
---------------
myrp_bot_add combine
myrp_bot_add resistance
myrp_bot_list
myrp_bot_respawn
myrp_bot_remove

Игровые команды администратора
------------------------------
/myrpbotadd combine
/myrpbotadd resistance
/myrpbotlist
/myrpbotrespawn
/myrpbotremove

Ограничения
-----------
- До 4 тестовых ботов всего, не более 2 на фракцию.
- Боты занимают реальные слоты сервера.
- Боты не получают Helix-персонажей и не создают записи персонажей в БД.
- Это неподвижные player-bots для проверки урона и PlayerDeath, а не полноценные
  AI-солдаты. На карте без navmesh они не будут нормально перемещаться.
- Команда myrp_bot_respawn возрождает только ботов, созданных этим плагином.
- Создание player-bots требует выделенного сервера; в одиночной игре API может
  быть недоступен.
- Архив подготовлен по присланному исходнику MatchHUD. Проверка синтаксиса
  средствами GMod и фактический запуск на вашем сервере ещё не выполнялись.

Проверка
--------
1. myrp_matchhud_status — убедитесь, что матч active=true.
2. myrp_bot_add combine
3. myrp_bot_add resistance
4. Убейте бота противоположной фракции.
5. Проверьте HUD и серверную строку [MYRP:MATCHHUD][KILL].
6. myrp_bot_respawn — повторите проверку.
