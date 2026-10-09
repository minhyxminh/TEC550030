import '../models/user.dart';
import '../models/membership.dart';
import '../models/gympoint.dart';
import 'auth_service.dart';
import 'gympoint_service.dart';
import 'catalogue_service.dart';

class AccountOverview {
  final User user;
  final int balance;
  final List<Membership> memberships;
  const AccountOverview(this.user, this.balance, this.memberships);
}

class AccountService {
  Future<AccountOverview> getOverview() async {
    final results = await Future.wait<Object>([
      AuthService().getCurrentUser(),
      GymPointService().getBalance(),
      CatalogueService().getMemberships(),
    ]);
    return AccountOverview(
      results[0] as User,
      (results[1] as GymPointBalance).balance,
      results[2] as List<Membership>,
    );
  }
}
