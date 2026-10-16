import 'bmi_result.dart';

class HealthTip {
  final String title, content;
  const HealthTip(this.title, this.content);
}

class HealthGuidance {
  final String title, summary;
  final List<HealthTip> tips;
  const HealthGuidance(this.title, this.summary, this.tips);
  static HealthGuidance forResult(BmiResult result) {
    final bmi = result.bmi;
    if (bmi < 18.5) {
      return HealthGuidance(
        'Tăng cân từ từ, ưu tiên sức mạnh',
        'BMI ${bmi.toStringAsFixed(1)} nằm dưới khoảng tham khảo người lớn. Theo dõi cả sức khỏe, khẩu phần và khả năng tập luyện, không chỉ con số trên cân.',
        const [
          HealthTip(
            'Vận động',
            'Ưu tiên bài tập sức mạnh nhẹ: squat với ghế, kéo dây hoặc tạ nhẹ khoảng 2 buổi/tuần, xen ngày nghỉ. Đi bộ nhẹ để duy trì thể lực; tránh tăng khối lượng cardio đột ngột khi ăn chưa đủ.',
          ),
          HealthTip(
            'Dinh dưỡng',
            'Ăn 3 bữa chính và thêm bữa phụ nếu ăn ít: sữa chua, sữa, trứng hoặc các loại hạt. Mỗi bữa có nguồn đạm và tinh bột. NHS gợi ý người lớn có thể thử thêm khoảng 300–500 kcal/ngày để tăng cân từ từ, rồi điều chỉnh theo diễn biến thực tế.',
          ),
          HealthTip(
            'Nước',
            'Uống rải đều trong ngày và bổ sung sau khi tập. Nếu nhanh no, tránh uống nhiều ngay trước bữa; có thể dùng sữa hoặc đồ uống giàu dinh dưỡng giữa các bữa, thay vì chỉ thêm nước ngọt.',
          ),
          HealthTip(
            'Giấc ngủ & phục hồi',
            'Giữ giờ ngủ đều, dành ngày nghỉ giữa các buổi tập sức mạnh. Nếu thường mệt, chóng mặt hoặc phục hồi kém, giảm cường độ và xem lại bữa ăn trước khi tăng bài tập.',
          ),
          HealthTip(
            'Theo dõi & hỗ trợ',
            'Cân trong điều kiện giống nhau 1–2 lần/tuần. Nếu sụt cân đột ngột, sụt cân không chủ ý hoặc ăn uống khó khăn kéo dài, nên trao đổi với bác sĩ/chuyên gia dinh dưỡng để tìm nguyên nhân.',
          ),
        ],
      );
    }
    if (bmi < 25) {
      return HealthGuidance(
        'Duy trì nhịp sống khỏe mạnh',
        'BMI ${bmi.toStringAsFixed(1)} đang trong khoảng tham khảo 18,5–<25. Ưu tiên duy trì thể lực và thói quen bền vững, không cần giảm cân chỉ để hạ BMI.',
        const [
          HealthTip(
            'Vận động',
            'Hướng tới ít nhất 150 phút vận động mức vừa mỗi tuần, như đi bộ nhanh, chia thành 30 phút trong 5 ngày; thêm ít nhất 2 ngày tập sức mạnh. Tăng dần nếu bạn mới bắt đầu và chọn bài tập mình có thể duy trì.',
          ),
          HealthTip(
            'Dinh dưỡng',
            'Duy trì bữa ăn đều với rau, trái cây, ngũ cốc và nguồn đạm đa dạng như cá, trứng, đậu. Điều chỉnh phần ăn theo mức vận động và cảm giác đói/no; không cần ăn kiêng khắt khe chỉ dựa trên BMI.',
          ),
          HealthTip(
            'Nước',
            'Ưu tiên nước lọc, uống đều trong ngày và thêm khi ra nhiều mồ hôi. Hạn chế dùng nước ngọt như nguồn nước chính; chuẩn bị chai nước cho buổi tập để dễ duy trì thói quen.',
          ),
          HealthTip(
            'Giấc ngủ & phục hồi',
            'Giữ giờ đi ngủ và thức dậy ổn định. Phân bổ buổi tập nặng xen ngày nhẹ, chú ý cảm giác tỉnh táo, đau cơ và hiệu suất để điều chỉnh khối lượng tập.',
          ),
          HealthTip(
            'Theo dõi & mục tiêu',
            'Theo dõi xu hướng cân nặng cùng vòng eo, sức bền và sức mạnh. BMI không phân biệt cơ với mỡ: nếu tập tạ nhiều, hãy đánh giá thêm các chỉ số khác trước khi thay đổi mục tiêu.',
          ),
        ],
      );
    }
    if (bmi < 30) {
      return HealthGuidance(
        'Điều chỉnh từng bước, theo dõi xu hướng',
        'BMI ${bmi.toStringAsFixed(1)} nằm trong nhóm thừa cân theo thang tham khảo. Bắt đầu từ những thay đổi nhỏ về bữa ăn và vận động; cân nặng hằng ngày có thể dao động do nước.',
        const [
          HealthTip(
            'Vận động',
            'Nếu ít vận động, bắt đầu đi bộ 10–15 phút mỗi lần rồi tăng dần. Hướng tới 150 phút/tuần ở mức vừa và 2 ngày tập sức mạnh. Đứng dậy đi lại thường xuyên khi làm việc; chọn bơi hoặc xe đạp nếu đi bộ gây khó chịu ở khớp.',
          ),
          HealthTip(
            'Dinh dưỡng',
            'Thử thay một đồ uống có đường bằng nước, thêm rau vào bữa chính và giữ nguồn đạm giúp no lâu. Ăn chậm, xem lại khẩu phần và các món ăn vặt thường xuyên; tránh nhịn bữa hoặc cắt bỏ hoàn toàn cả nhóm thực phẩm.',
          ),
          HealthTip(
            'Nước',
            'Uống nước đều trước và sau vận động. Kiểm tra đường trong trà sữa, nước trái cây đóng chai và đồ uống thể thao; không dùng nhịn nước hoặc ép ra mồ hôi để giảm số cân.',
          ),
          HealthTip(
            'Giấc ngủ & căng thẳng',
            'Duy trì giờ ngủ đều và ghi nhận những lúc ăn vì căng thẳng hoặc thức khuya. Chuẩn bị bữa phụ phù hợp và dành thời gian thư giãn để hỗ trợ thói quen ăn uống ổn định.',
          ),
          HealthTip(
            'Theo dõi & hỗ trợ',
            'Cân cùng thời điểm 1–2 lần/tuần và nhìn xu hướng vài tuần. Nếu muốn giảm cân, ưu tiên tiến độ từ từ; trao đổi với chuyên gia để chọn mục tiêu phù hợp với bệnh nền, thuốc đang dùng và mức vận động.',
          ),
        ],
      );
    }
    final high = bmi >= 35;
    return HealthGuidance(
      high
          ? 'Ưu tiên đánh giá sức khỏe và kế hoạch phù hợp'
          : 'Xây dựng kế hoạch kiểm soát cân nặng bền vững',
      'BMI ${bmi.toStringAsFixed(1)} ${high ? 'từ 35 trở lên' : 'từ 30 đến dưới 35'}. BMI là chỉ số sàng lọc; cần xem thêm vòng eo, huyết áp, đường huyết và tình trạng thực tế để chọn mục tiêu.',
      [
        HealthTip(
          'Vận động',
          high
              ? 'Bắt đầu với hoạt động ít chịu lực như đi bộ ngắn trên mặt phẳng, đạp xe tại chỗ hoặc vận động dưới nước. Chia thành các đợt ngắn theo sức; nếu có đau khớp, khó thở hoặc bệnh tim mạch, hỏi nhân viên y tế trước khi tăng cường độ.'
              : 'Bắt đầu bằng những đợt đi bộ ngắn hoặc xe đạp nhẹ, tăng dần về thời lượng. Khi phù hợp với sức khỏe, hướng tới 150 phút/tuần ở mức vừa và tập sức mạnh 2 ngày/tuần; ưu tiên bài ít gây đau khớp.',
        ),
        const HealthTip(
          'Dinh dưỡng',
          'Ưu tiên bữa ăn có kế hoạch: rau, nguồn đạm và tinh bột với khẩu phần phù hợp. Giảm dần nước ngọt, món chiên và ăn vặt nhiều năng lượng. Nên cùng chuyên gia xây dựng thay đổi thực tế; không tự dùng thuốc giảm cân hoặc chế độ nhịn ăn cực đoan.',
        ),
        const HealthTip(
          'Nước',
          'Chọn nước lọc thay cho đồ uống nhiều đường và bổ sung khi tập. Không ép uống một lượng cố định để giảm cân; nếu đang được hướng dẫn hạn chế dịch do bệnh tim/thận, hãy theo hướng dẫn riêng của bác sĩ.',
        ),
        const HealthTip(
          'Giấc ngủ & phục hồi',
          'Giữ lịch ngủ ổn định và tăng khối lượng tập chậm. Nếu ngáy to, thường thức giấc hoặc buồn ngủ nhiều ban ngày, nên trao đổi với bác sĩ để được đánh giá; không chỉ cố tập nặng hơn để khắc phục mệt mỏi.',
        ),
        HealthTip(
          'Theo dõi & hỗ trợ',
          high
              ? 'Nên đặt lịch với bác sĩ/chuyên gia dinh dưỡng để đánh giá các yếu tố liên quan và lập kế hoạch cá nhân. Ghi lại xu hướng cân, vòng eo và triệu chứng; với BMI từ 40, ưu tiên được đánh giá chuyên môn trước khi tự áp dụng chương trình giảm cân mạnh.'
              : 'Theo dõi xu hướng cân theo tuần, vòng eo và khả năng vận động. Nên kiểm tra huyết áp, đường huyết và trao đổi với bác sĩ nếu có bệnh nền để chọn cách kiểm soát cân nặng phù hợp.',
        ),
      ],
    );
  }
}
