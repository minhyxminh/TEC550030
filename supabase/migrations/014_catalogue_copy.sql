-- Replace sample-data names and descriptions with real catalogue copy.
update public.trainers
set name = 'PT Minh',
    description = 'Chuyên huấn luyện sức mạnh với các bài compound như squat, deadlift và bench press. Minh giúp bạn tập đúng kỹ thuật và tăng tạ an toàn theo giáo án từng tuần.'
where id = '30000000-0000-4000-8000-000000000001';

update public.trainers
set name = 'PT Lan',
    description = 'Tập trung vào thể lực tổng quát và độ linh hoạt của khớp. Lan kết hợp mobility, core và cardio nhẹ, phù hợp người mới bắt đầu hoặc cần cải thiện tư thế.'
where id = '30000000-0000-4000-8000-000000000002';

update public.trainers
set description = 'Chuyên các chương trình giảm mỡ và săn chắc cơ thể. Josephine kết hợp bài sức mạnh, HIIT và hướng dẫn ăn uống cơ bản để bạn giữ dáng bền vững.'
where id = '031109d5-a072-4bf6-9916-3741743cfdf3' and coalesce(description, '') = '';

update public.rewards
set description = 'Voucher một phần đồ ăn nhẹ tại quầy GymFlow sau buổi tập.'
where id = '7f5afadc-81ab-45ba-89b2-ab22c8944ce0';

update public.rewards
set description = 'Bình nước thể thao GymFlow, tiện mang theo mỗi buổi tập.'
where id = '817a5512-f3d6-464b-b561-2d446dcc5dd6';
