-- Run after 001_initial_schema.sql. Re-running never resets stock or costs.
begin;
insert into public.memberships(id, name, description, price_vnd, duration_days, points_per_checkin) values
('10000000-0000-4000-8000-000000000001', 'Basic', '5 GP tối đa một lần mỗi ngày check-in; 100 GP khi kích hoạt.', 300000, 30, 5),
('10000000-0000-4000-8000-000000000002', 'Premium', '5 GP tối đa một lần mỗi ngày check-in; 200 GP khi kích hoạt.', 500000, 30, 5),
('10000000-0000-4000-8000-000000000003', 'VIP', '5 GP tối đa một lần mỗi ngày check-in; 300 GP khi kích hoạt.', 800000, 30, 5)
on conflict do nothing;

insert into public.rewards(id, name, description, points, stock, image_url) values
('20000000-0000-4000-8000-000000000001', 'Nước khoáng', 'Một chai nước sau buổi tập.', 20, 50, ''),
('20000000-0000-4000-8000-000000000002', 'Thanh protein', 'Bữa phụ sau buổi tập.', 50, 30, ''),
('20000000-0000-4000-8000-000000000003', 'Khăn tập', 'Khăn tập GymFlow.', 100, 20, ''),
('20000000-0000-4000-8000-000000000004', 'Voucher đồ uống', 'Voucher giảm 20% một đồ uống tại quầy GymFlow.', 150, 10, '')
on conflict do nothing;

insert into public.trainers(id, name, specialty, experience_years, description) values
('30000000-0000-4000-8000-000000000001', 'PT Minh', 'Strength training', 3, 'Chuyên huấn luyện sức mạnh với các bài compound như squat, deadlift và bench press. Minh giúp bạn tập đúng kỹ thuật và tăng tạ an toàn theo giáo án từng tuần.'),
('30000000-0000-4000-8000-000000000002', 'PT Lan', 'Fitness & mobility', 4, 'Tập trung vào thể lực tổng quát và độ linh hoạt của khớp. Lan kết hợp mobility, core và cardio nhẹ, phù hợp người mới bắt đầu hoặc cần cải thiện tư thế.')
on conflict do nothing;
commit;
