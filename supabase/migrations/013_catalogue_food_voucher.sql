-- Replace the placeholder "khăn" reward with the food voucher shown in the app.
update public.rewards
set name = 'Voucher thức ăn',
    description = 'Voucher một phần đồ ăn nhẹ tại quầy GymFlow sau buổi tập.'
where id = '7f5afadc-81ab-45ba-89b2-ab22c8944ce0';
