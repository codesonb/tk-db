USE TKCar_UnitTest


INSERT INTO SystemConfig(dict_key, grp_key, c_value1, c_value2, c_order)
SELECT 'TRANSLATION', 'CONFIG_FIELD', 'srv_plan', '計劃', 1 UNION ALL
SELECT 'TRANSLATION', 'CONFIG_FIELD', 'today', '日期', 2 UNION ALL
SELECT 'TRANSLATION', 'CONFIG_FIELD', 'signal', '類型', 3 UNION ALL
SELECT 'TRANSLATION', 'CONFIG_FIELD', 'loc_key', '車場', 4 UNION ALL
SELECT 'TRANSLATION', 'CONFIG_FIELD', 'cd_license', '車牌', 5 UNION ALL
SELECT 'TRANSLATION', 'CONFIG_FIELD', 'loc_psn', '車位', 6 UNION ALL
SELECT 'TRANSLATION', 'CONFIG_FIELD', 'yrmo', '月份', 7 UNION ALL
SELECT 'TRANSLATION', 'CONFIG_FIELD', 'total', '總數', 8