-- Reference configuration only: no fictional people in local or production.
insert into public.products(id,name_ar,name_en,description_ar,description_en,active,sort_order) values
('plus','بلس','Plus','خطة مقترحة لفرص اكتشاف إضافية. المزايا غير مفعلة.','Proposed additional discovery plan. Benefits are not enabled.',false,1),
('premium','بريميوم','Premium','خطة مقترحة لتخصيص الملف. المزايا غير مفعلة.','Proposed profile customization plan. Benefits are not enabled.',false,2)
on conflict do nothing;
