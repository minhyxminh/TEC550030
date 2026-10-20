// @ts-nocheck
// Generated from backend/src/app.js and supabase.js. Do not edit by hand.
// Rebuild with: cd backend && npm.cmd run build:edge
import express from 'npm:express@5.2.1';
import cors from 'npm:cors@2.8.6';
import helmet from 'npm:helmet@8.3.0';
import { rateLimit } from 'npm:express-rate-limit@8.7.1';
import { z } from 'npm:zod@4.6.5';

const credentials = z.object({
  email: z.email().max(254).transform(value => value.trim().toLowerCase()),
  password: z.string().min(1).max(128),
}).strict();
const registration = credentials.extend({
  name: z.string().trim().min(1).max(100),
  password: z.string().min(8).max(128),
});
const refreshBody = z.object({ refresh_token: z.string().min(1).max(4096) }).strict();
const emailAddress = z.email().max(254).transform(value => value.trim().toLowerCase());
const uuid = z.uuid();
const page = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(100),
  offset: z.coerce.number().int().min(0).max(100000).default(0),
});

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function databaseResult(result) {
  if (result.error) throw new ApiError(503, 'DATABASE_ERROR', 'Không thể đọc dữ liệu. Kiểm tra cấu hình Supabase và migration.');
  return result.data;
}

const businessErrors = {
  UNAUTHORIZED: [401, 'Cần đăng nhập.'], FORBIDDEN: [403, 'Chỉ quản trị viên được thực hiện thao tác này.'],
  NOT_FOUND: [404, 'Không tìm thấy dữ liệu.'], PROFILE_NOT_FOUND: [404, 'Chưa có hồ sơ người dùng.'],
  INVALID_INPUT: [400, 'Dữ liệu không hợp lệ.'], INVALID_QR: [400, 'QR không hợp lệ, đã hết hạn hoặc bị thu hồi.'],
  GYM_REQUIRED: [403, 'Bạn cần chọn cơ sở trước khi check-in.'], WRONG_GYM: [403, 'Buổi tập không khớp cơ sở đã chọn.'],
  GYM_NOT_FOUND: [404, 'Cơ sở không tồn tại hoặc đang ngừng hoạt động.'],
  OPEN_SESSION: [409, 'Hãy check-out trước khi đổi cơ sở tập.'],
  MEMBERSHIP_REQUIRED: [403, 'Bạn cần gói tập còn hạn để check-in.'],
  MEMBERSHIP_NOT_ACTIVE: [409, 'Hội viên không có membership đang hoạt động.'],
  ALREADY_CHECKED_IN: [409, 'Bạn đang có buổi tập chưa check-out.'],
  INSUFFICIENT_POINTS: [409, 'Bạn chưa đủ GymPoint để đổi quà.'], OUT_OF_STOCK: [409, 'Phần quà đã hết hàng.'],
  REQUEST_CONFLICT: [409, 'Yêu cầu thử lại không khớp yêu cầu ban đầu.'],
  PENDING_ORDER_EXISTS: [409, 'Bạn đã có đơn gói tập chờ duyệt.'],
  INVALID_SLOT: [400, 'Chọn giờ tròn từ 06:00 đến 21:00 trong 30 ngày tới.'],
  BOOKING_STARTED: [409, 'Buổi tập đã bắt đầu, không thể hủy.'], ORDER_PROCESSED: [409, 'Đơn này đã được xử lý.'],
  GYM_NOT_FOUND: [404, 'Cơ sở không tồn tại hoặc đang ngừng hoạt động.'],
  OPEN_SESSION: [409, 'Hãy check-out trước khi đổi cơ sở tập.'],
  CANNOT_SWIPE_SELF: [400, 'Không thể tự kết nối với chính mình.'],
  NOT_MATCHED: [409, 'Chỉ có thể thêm Gym Buddy đã match với bạn.'],
  PAYMENT_REQUIRED: [409, 'Đơn thanh toán phải được xác nhận đã nhận tiền trước khi kích hoạt.'],
  PAYMENT_NOT_CONFIGURED: [409, 'Gói tập này chưa được cấu hình số tiền thanh toán demo.'],
};
async function workflow(client, name, action, payload = {}) {
  const result = await client.rpc(name, { action, payload });
  if (result.error) {
    const known = businessErrors[result.error.message];
    if (known) throw new ApiError(known[0], result.error.message, known[1]);
    if (result.error.code === '23505') throw new ApiError(409, 'SLOT_UNAVAILABLE', 'Lịch đã được đặt. Vui lòng tải lại và chọn giờ khác.');
    if (['23514', '22P02', '22007', '22008'].includes(result.error.code)) throw new ApiError(400, 'INVALID_INPUT', 'Dữ liệu không hợp lệ.');
    return databaseResult(result);
  }
  return result.data;
}
async function hashToken(token) {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return Array.from(new Uint8Array(hash), byte => byte.toString(16).padStart(2, '0')).join('');
}
export function createQrToken() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let token;
  do {
    token = '';
    while (token.length < 10) {
      const bytes = crypto.getRandomValues(new Uint8Array(32));
      for (const byte of bytes) {
        // 252 is divisible by 36: rejection sampling avoids modulo bias.
        if (byte < 252) token += alphabet[byte % alphabet.length];
        if (token.length === 10) break;
      }
    }
  } while (!/[A-Z]/.test(token) || !/[0-9]/.test(token));
  return token;
}
const requestKey = z.uuid();
const dateString = z.iso.date();
const gymId = z.string().trim().min(1).max(100);

function sessionResponse(data) {
  return {
    user: { id: data.user.id, email: data.user.email, name: data.user.user_metadata?.name ?? '' },
    access_token: data.session?.access_token ?? null,
    refresh_token: data.session?.refresh_token ?? null,
    expires_in: data.session?.expires_in ?? null,
    requires_email_confirmation: !data.session,
  };
}

function paymentResponse(order, paymentConfig = {}) {
  const bankId = paymentConfig.bankId?.trim();
  const accountNo = paymentConfig.accountNo?.trim();
  const accountName = paymentConfig.accountName?.trim();
  const ready = Boolean(bankId && accountNo && accountName);
  const paymentCode = order?.payment_code ?? '';
  // VietinBank personal/business-household accounts linked through SePay
  // require SEVQR in the transfer memo so transaction notifications are pushed.
  const description = bankId?.toLowerCase() === 'vietinbank'
    ? `SEVQR ${paymentCode}`
    : paymentCode;
  let qrUrl = null;
  if (ready && order?.payment_amount_vnd && description) {
    const params = new URLSearchParams({
      acc: accountNo,
      bank: bankId,
      amount: String(order.payment_amount_vnd),
      des: description,
      template: 'compact',
      showinfo: 'true',
      holder: accountName,
    });
    qrUrl = `https://vietqr.app/img?${params.toString()}`;
  }
  return {
    ...order,
    payment_ready: ready,
    qr_url: qrUrl,
    bank: ready ? {
      bank_id: bankId,
      account_no: accountNo,
      account_name: accountName,
    } : null,
  };
}

function mapRpcError(result) {
  const known = businessErrors[result.error?.message];
  if (known) throw new ApiError(known[0], result.error.message, known[1]);
  return databaseResult(result);
}

export function createApp({
  createSupabase,
  createServiceSupabase = null,
  paymentConfig = {},
  corsOrigins = [],
  trustProxy = false,
}) {
  const app = express();
  app.set('trust proxy', trustProxy);
  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: corsOrigins }));
  app.use(express.json({ limit: '16kb' }));
  app.use('/auth', rateLimit({
    windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false,
    message: { code: 'RATE_LIMITED', message: 'Quá nhiều yêu cầu đăng nhập. Vui lòng thử lại sau.' },
  }));

  // Verifies Data API, rewards table and read policy, rather than just returning OK.
  app.get('/health', async (_req, res) => {
    databaseResult(await createSupabase().from('rewards').select('id', { head: true, count: 'exact' }));
    res.json({ status: 'ok', database: 'connected' });
  });

  app.post('/auth/register', async (req, res) => {
    const { name, email, password } = registration.parse(req.body);
    const { data, error } = await createSupabase().auth.signUp({ email, password, options: { data: { name } } });
    if (error || !data.user) throw new ApiError(400, 'REGISTER_FAILED', 'Không thể đăng ký. Kiểm tra email, mật khẩu hoặc thử lại sau.');
    // Supabase may obfuscate an existing account instead of disclosing its existence.
    res.status(201).json({ ...sessionResponse(data), message: data.session ? 'Đăng ký thành công.' : 'Kiểm tra email để xác nhận tài khoản trước khi đăng nhập.' });
  });

  app.post('/auth/login', async (req, res) => {
    const input = credentials.parse(req.body);
    const { data, error } = await createSupabase().auth.signInWithPassword(input);
    if (error || !data.session || !data.user) throw new ApiError(401, 'LOGIN_FAILED', 'Email/mật khẩu không hợp lệ hoặc email chưa được xác nhận.');
    res.json(sessionResponse(data));
  });

  app.post('/auth/refresh', async (req, res) => {
    const input = refreshBody.parse(req.body);
    const { data, error } = await createSupabase().auth.refreshSession(input);
    if (error || !data.session || !data.user) throw new ApiError(401, 'INVALID_REFRESH_TOKEN', 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
    res.json(sessionResponse(data));
  });
  app.post('/auth/forgot-password', async (req, res) => {
    const { email } = z.object({ email: emailAddress }).strict().parse(req.body);
    await createSupabase().auth.resetPasswordForEmail(email);
    // Keep provider delivery failures in Supabase Auth logs. A different response
    // for SMTP rejection could disclose whether an address has an account.
    res.json({ message: 'Nếu email đã được đăng ký, bạn sẽ nhận được mã xác nhận đặt lại mật khẩu.' });
  });
  app.post('/auth/reset-password', async (req, res) => {
    const { email, token, password } = z.object({
      email: emailAddress, token: z.string().regex(/^\d{6,10}$/), password: z.string().min(8).max(128),
    }).strict().parse(req.body);
    const client = createSupabase();
    const verified = await client.auth.verifyOtp({ email, token, type: 'recovery' });
    if (verified.error || !verified.data.session || !verified.data.user) {
      throw new ApiError(400, 'INVALID_RECOVERY_CODE', 'Mã xác nhận không đúng hoặc đã hết hạn. Vui lòng yêu cầu mã mới.');
    }
    const { error } = await client.auth.updateUser({ password });
    if (error) throw new ApiError(400, 'PASSWORD_UPDATE_FAILED', 'Không thể đổi mật khẩu. Chọn mật khẩu mới đủ mạnh và thử lại.');
    // Recovery credentials stay on this request; never save a recovery login in the app.
    await client.auth.signOut({ scope: 'global' });
    res.json({ message: 'Đã đổi mật khẩu. Vui lòng đăng nhập bằng mật khẩu mới.' });
  });

  const catalogues = [
    ['rewards', 'id,name,description,points,stock,image_url,created_at'],
    ['memberships', 'id,name,description,price_vnd,duration_days,points_per_checkin,points_on_activation,created_at'],
    ['trainers', 'id,name,specialty,experience_years,description,image_url,created_at'],
  ];
  for (const [table, fields] of catalogues) {
    app.get(`/${table}`, async (req, res) => {
      const { limit, offset } = page.parse(req.query);
      res.json(databaseResult(await createSupabase().from(table).select(fields)
        .eq('is_active', true).order('created_at').order('id').range(offset, offset + limit - 1)));
    });
    app.get(`/${table}/:id`, async (req, res) => {
      const id = uuid.parse(req.params.id);
      const record = databaseResult(await createSupabase().from(table).select(fields).eq('id', id).eq('is_active', true).maybeSingle());
      if (!record) throw new ApiError(404, 'NOT_FOUND', 'Không tìm thấy dữ liệu.');
      res.json(record);
    });
  }
  app.get('/gyms', async (req, res) => {
    const { limit, offset } = page.parse(req.query);
    res.json(databaseResult(await createSupabase().from('gyms')
      .select('id,name,address,district,latitude,longitude,opening_hours')
      .eq('is_active', true).order('district').order('name')
      .range(offset, offset + limit - 1)));
  });
  app.get('/gyms', async (req, res) => {
    const { limit, offset } = page.parse(req.query);
    res.json(databaseResult(await createSupabase().from('gyms')
      .select('id,name,address,district,latitude,longitude,opening_hours')
      .eq('is_active', true).order('district').order('name')
      .range(offset, offset + limit - 1)));
  });

  // Token is verified with Supabase Auth. RLS also checks the user JWT on reads.
  const requireAuth = async (req, _res, next) => {
    const match = /^Bearer ([^\s]+)$/i.exec(req.headers.authorization ?? '');
    if (!match) throw new ApiError(401, 'UNAUTHORIZED', 'Cần đăng nhập.');
    const client = createSupabase(match[1]);
    const { data, error } = await client.auth.getUser(match[1]);
    if (error || !data.user) throw new ApiError(401, 'UNAUTHORIZED', 'Token không hợp lệ hoặc đã hết hạn.');
    req.supabase = client;
    req.userId = data.user.id;
    req.authUser = data.user;
    next();
  };

  app.get('/me', requireAuth, async (req, res) => {
    const user = databaseResult(await req.supabase.rpc('gymflow_my_profile'));
    if (!user) throw new ApiError(404, 'PROFILE_NOT_FOUND', 'Chưa có hồ sơ. Kiểm tra migration và trigger tạo user.');
    const avatar = user.avatar_path ? req.supabase.storage.from('gymflow-images').getPublicUrl(user.avatar_path).data.publicUrl : null;
    res.json({ ...user, email: req.authUser.email, avatar_url: avatar });
  });

  app.get('/points/balance', requireAuth, async (req, res) => {
    const balance = databaseResult(await req.supabase.rpc('get_my_point_balance'));
    res.json({ balance: Number(balance) });
  });

  app.post('/chat/open', requireAuth, async (req, res) => {
    z.object({}).strict().parse(req.body ?? {});
    res.json(await workflow(req.supabase, 'gymflow_chat', 'open'));
  });
  app.get('/chat/inbox', requireAuth, async (req, res) => {
    res.json(await workflow(req.supabase, 'gymflow_chat', 'inbox', page.parse(req.query)));
  });
  app.get('/chat/:id/messages', requireAuth, async (req, res) => {
    const input = z.object({ before: z.coerce.number().int().positive().optional(),
      limit: z.coerce.number().int().min(1).max(100).default(50) }).strict().parse(req.query);
    res.json(await workflow(req.supabase, 'gymflow_chat', 'messages', {
      ...input, conversation_id: uuid.parse(req.params.id),
    }));
  });
  app.post('/chat/:id/messages', requireAuth, async (req, res) => {
    const input = z.object({ content: z.string().trim().min(1).max(2000), client_id: uuid }).strict().parse(req.body);
    res.json(await workflow(req.supabase, 'gymflow_chat', 'send', {
      ...input, conversation_id: uuid.parse(req.params.id),
    }));
  });
  app.post('/chat/:id/read', requireAuth, async (req, res) => {
    const input = z.object({ through: z.number().int().positive() }).strict().parse(req.body);
    res.json(await workflow(req.supabase, 'gymflow_chat', 'read', {
      ...input, conversation_id: uuid.parse(req.params.id),
    }));
  });

  const buddyProfileSchema = z.object({
    enabled: z.boolean().optional(),
    age: z.number().int().min(16).max(100).nullable().optional(),
    gender: z.string().trim().max(50).nullable().optional(),
    show_age: z.boolean().optional(),
    show_gender: z.boolean().optional(),
    fitness_goal: z.string().trim().max(200).nullable().optional(),
    experience_level: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']).nullable().optional(),
    favorite_workouts: z.array(z.string().trim().max(100)).max(20).optional(),
    preferred_workout_times: z.array(z.string().trim().max(100)).max(20).optional(),
    workout_style: z.array(z.string().trim().max(100)).max(20).optional(),
    bio: z.string().trim().max(1000).nullable().optional(),
    onboarding_completed: z.boolean().optional(),
    looking_for_partner: z.boolean().optional(),
    partner_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
    partner_start_time: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/).nullable().optional(),
    partner_end_time: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/).nullable().optional(),
    partner_workout: z.string().trim().max(200).nullable().optional(),
    partner_gym_id: z.string().trim().max(100).nullable().optional(),
    partner_note: z.string().trim().max(1000).nullable().optional(),
  }).strict();

  app.get('/buddy/profile', requireAuth, async (req, res) => {
    const profile = await workflow(req.supabase, 'gymflow_buddy', 'PROFILE_GET');
    if (!profile) return res.json(null);
    const avatar = profile.avatar_path ? req.supabase.storage.from('gymflow-images').getPublicUrl(profile.avatar_path).data.publicUrl : null;
    res.json({ ...profile, avatar_url: avatar });
  });

  app.post('/buddy/profile', requireAuth, async (req, res) => {
    const payload = buddyProfileSchema.parse(req.body);
    const profile = await workflow(req.supabase, 'gymflow_buddy', 'PROFILE_UPSERT', payload);
    const avatar = profile?.avatar_path ? req.supabase.storage.from('gymflow-images').getPublicUrl(profile.avatar_path).data.publicUrl : null;
    res.json({ ...profile, avatar_url: avatar });
  });

  app.get('/buddy/feed', requireAuth, async (req, res) => {
    const query = z.object({ limit: z.coerce.number().int().min(1).max(100).default(20) }).strict().parse(req.query);
    const feed = await workflow(req.supabase, 'gymflow_buddy', 'FEED', query);
    const candidates = (feed?.candidates || []).map(c => ({
      ...c,
      avatar_url: c.avatar_path ? req.supabase.storage.from('gymflow-images').getPublicUrl(c.avatar_path).data.publicUrl : null,
    }));
    res.json({ candidates });
  });

  app.post('/buddy/swipe', requireAuth, async (req, res) => {
    const payload = z.object({
      target_id: uuid,
      action: z.enum(['LIKE', 'PASS']),
    }).strict().parse(req.body);
    res.json(await workflow(req.supabase, 'gymflow_buddy', 'SWIPE', payload));
  });

  app.get('/buddy/matches', requireAuth, async (req, res) => {
    const data = await workflow(req.supabase, 'gymflow_buddy', 'MATCHES');
    const matches = (data?.matches || []).map(m => ({
      ...m,
      other_avatar_url: m.other_avatar_path ? req.supabase.storage.from('gymflow-images').getPublicUrl(m.other_avatar_path).data.publicUrl : null,
    }));
    res.json({ matches });
  });

  app.post('/buddy/groups', requireAuth, async (req, res) => {
    const payload = z.object({
      title: z.string().trim().min(1).max(80),
      member_ids: z.array(uuid).min(2).max(20),
    }).strict().parse(req.body);
    res.status(201).json(await workflow(req.supabase, 'gymflow_buddy', 'GROUP_CREATE', payload));
  });

  app.get('/points/history', requireAuth, async (req, res) => {
    const { limit, offset } = page.parse(req.query);
    res.json(databaseResult(await req.supabase.from('point_transactions')
      .select('id,points,reason,type,created_at').eq('user_id', req.userId)
      .order('created_at', { ascending: false }).order('id').range(offset, offset + limit - 1)));
  });

  const command = (action, schema) => async (req, res) => {
    const input = schema.parse({ ...req.body, ...req.params });
    res.json(await workflow(req.supabase, 'gymflow_command', action, input));
  };
  app.patch('/me', requireAuth, async (req, res) => {
    const payload = z.object({ name: z.string().trim().min(1).max(100), avatar_path: z.string().max(300).nullable().optional() }).strict().parse(req.body);
    const result = await req.supabase.rpc('gymflow_update_profile', { payload });
    if (result.error?.message === 'INVALID_IMAGE') throw new ApiError(400, 'INVALID_IMAGE', 'Ảnh đại diện không hợp lệ. Vui lòng tải lại ảnh.');
    res.json(databaseResult(result));
  });
  app.post('/me/home-gym', requireAuth, async (req, res) => {
    const input = z.object({ gym_id: gymId }).strict().parse(req.body);
    const result = await req.supabase.rpc('gymflow_select_home_gym', {
      gym_id_input: input.gym_id,
    });
    const known = businessErrors[result.error?.message];
    if (known) throw new ApiError(known[0], result.error.message, known[1]);
    res.json(databaseResult(result));
  });
  app.post('/me/home-gym', requireAuth, async (req, res) => {
    const input = z.object({ gym_id: gymId }).strict().parse(req.body);
    const result = await req.supabase.rpc('gymflow_select_home_gym', {
      gym_id_input: input.gym_id,
    });
    const known = businessErrors[result.error?.message];
    if (known) throw new ApiError(known[0], result.error.message, known[1]);
    res.json(databaseResult(result));
  });
  app.post('/media/:kind', requireAuth, express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '3mb' }), async (req, res) => {
    const kind = z.enum(['avatars', 'rewards', 'trainers']).parse(req.params.kind);
    if (kind !== 'avatars') {
      const profile = databaseResult(await req.supabase.from('users').select('role').eq('id', req.userId).maybeSingle());
      if (profile?.role !== 'ADMIN') throw new ApiError(403, 'FORBIDDEN', 'Chỉ quản trị viên được tải ảnh danh mục.');
    }
    const bytes = req.body;
    const mime = req.get('Content-Type')?.split(';')[0];
    const valid = bytes instanceof Uint8Array && (
      (mime === 'image/jpeg' && bytes.length >= 4 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) ||
      (mime === 'image/png' && bytes.length >= 8 && [137,80,78,71,13,10,26,10].every((b,i)=>bytes[i]===b)) ||
      (mime === 'image/webp' && bytes.length >= 12 && String.fromCharCode(...bytes.slice(0,4)) === 'RIFF' && String.fromCharCode(...bytes.slice(8,12)) === 'WEBP')
    );
    if (!valid) throw new ApiError(400, 'INVALID_IMAGE', 'Chọn ảnh JPG, PNG hoặc WebP tối đa 3 MB.');
    const ext = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' }[mime];
    const path = `${kind}/${req.userId}/${crypto.randomUUID()}.${ext}`;
    const bucket = req.supabase.storage.from('gymflow-images');
    const { error } = await bucket.upload(path, bytes, { contentType: mime, upsert: false });
    if (error) throw new ApiError(503, 'IMAGE_UPLOAD_FAILED', 'Không thể tải ảnh lên. Kiểm tra kết nối và thử lại.');
    res.status(201).json({ path, url: bucket.getPublicUrl(path).data.publicUrl });
  });
  app.post('/gym/check-in', requireAuth, async (req, res) => {
    const { token } = z.object({ token: z.string().min(1).max(512) }).strict().parse(req.body);
    const normalized = /^[A-Za-z0-9]{10}$/.test(token.trim()) ? token.trim().toUpperCase() : token;
    res.json(await workflow(req.supabase, 'gymflow_command', 'check_in', { token_hash: await hashToken(normalized) }));
  });
  app.post('/gym/check-out', requireAuth, command('check_out', z.object({ session_id: uuid }).strict()));
  app.get('/gym/session', requireAuth, async (req, res) => {
    res.json(databaseResult(await req.supabase.from('gym_sessions').select('*').eq('user_id', req.userId).is('check_out_at', null).maybeSingle()));
  });
  app.get('/gym/:gym_id/occupancy', requireAuth, async (req, res) => {
    res.json(await workflow(req.supabase, 'gymflow_read', 'occupancy', { gym_id: gymId.parse(req.params.gym_id) }));
  });
  app.get('/gym/:gym_id/hourly', requireAuth, async (req, res) => {
    const input = z.object({ date: dateString.optional() }).strict().parse(req.query);
    res.json(await workflow(req.supabase, 'gymflow_read', 'hourly', { ...input, gym_id: gymId.parse(req.params.gym_id) }));
  });
  app.post('/redemptions', requireAuth, command('redeem', z.object({ reward_id: uuid, idempotency_key: requestKey }).strict()));
  // Legacy manual-approval order route remains for backwards compatibility.
  app.post('/membership-orders', requireAuth, command('membership_order', z.object({ membership_id: uuid, idempotency_key: requestKey }).strict()));

  app.post('/payments/membership-orders', requireAuth, async (req, res) => {
    const input = z.object({
      membership_id: uuid,
      idempotency_key: requestKey,
    }).strict().parse(req.body);
    const result = await req.supabase.rpc('gymflow_create_membership_payment', {
      membership_id_input: input.membership_id,
      idempotency_key_input: input.idempotency_key,
    });
    res.status(201).json(paymentResponse(mapRpcError(result), paymentConfig));
  });

  app.get('/payments/membership-orders/:id', requireAuth, async (req, res) => {
    const result = await req.supabase.rpc('gymflow_get_membership_payment', {
      order_id_input: uuid.parse(req.params.id),
    });
    res.json(paymentResponse(mapRpcError(result), paymentConfig));
  });

  // SePay calls this public endpoint after a bank transaction. The secret is
  // configured in SePay + Supabase secrets and is never exposed to Flutter.
  app.post('/webhooks/sepay', async (req, res) => {
    const expectedKey = paymentConfig.sepayApiKey;
    if (!expectedKey || !createServiceSupabase) {
      throw new ApiError(503, 'PAYMENT_NOT_CONFIGURED', 'Webhook thanh toán chưa được cấu hình.');
    }
    if (req.headers.authorization !== `Apikey ${expectedKey}`) {
      throw new ApiError(401, 'UNAUTHORIZED', 'Webhook không hợp lệ.');
    }

    const input = z.object({
      id: z.union([z.number().int(), z.string().min(1).max(100)]),
      gateway: z.string().max(100).optional(),
      transactionDate: z.string().max(50).optional(),
      accountNumber: z.string().max(100).optional(),
      code: z.string().max(100).nullable().optional(),
      content: z.string().max(1000).default(''),
      transferType: z.string().max(20),
      transferAmount: z.coerce.number().int().positive(),
      referenceCode: z.string().max(200).nullable().optional(),
    }).passthrough().parse(req.body);

    if (input.transferType.toLowerCase() !== 'in') {
      return res.json({ success: true, ignored: true, reason: 'NOT_INCOMING' });
    }

    const codeCandidate = input.code?.trim().toUpperCase();
    const contentMatch = input.content.toUpperCase().match(/GF[A-Z0-9]{12}/);
    const paymentCode = codeCandidate?.match(/^GF[A-Z0-9]{12}$/)?.[0]
      ?? contentMatch?.[0]
      ?? null;
    if (!paymentCode) {
      return res.json({ success: true, ignored: true, reason: 'NO_PAYMENT_CODE' });
    }

    let transactionAt = null;
    if (input.transactionDate) {
      const normalized = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(input.transactionDate)
        ? input.transactionDate.replace(' ', 'T') + '+07:00'
        : input.transactionDate;
      if (!Number.isNaN(Date.parse(normalized))) transactionAt = normalized;
    }

    const service = createServiceSupabase();
    const result = await service.rpc('gymflow_confirm_membership_payment', {
      payment_code_input: paymentCode,
      provider_transaction_id_input: String(input.id),
      transfer_amount_input: input.transferAmount,
      transfer_content_input: input.content,
      provider_transaction_at_input: transactionAt,
    });
    mapRpcError(result);
    // SePay treats the webhook as delivered only when the response body is
    // exactly {"success":true} with HTTP 200/201.
    res.json({ success: true });
  });

  app.get('/trainers/:id/slots', requireAuth, async (req, res) => {
    const input = z.object({ date: dateString }).strict().parse(req.query);
    res.json(await workflow(req.supabase, 'gymflow_read', 'pt_slots', { ...input, trainer_id: uuid.parse(req.params.id) }));
  });
  app.post('/pt-bookings', requireAuth, command('book_pt', z.object({ trainer_id: uuid, slot: z.iso.datetime({ offset: true }), idempotency_key: requestKey }).strict()));
  app.post('/pt-bookings/:id/cancel', requireAuth, command('cancel_pt', z.object({ id: uuid }).strict()));
  app.get('/activity', requireAuth, async (req, res) => {
    res.json(await workflow(req.supabase, 'gymflow_read', 'history', page.parse(req.query)));
  });
  for (const [path, key] of [['gym/sessions', 'sessions'], ['redemptions', 'redemptions'], ['membership-orders', 'orders'], ['pt-bookings', 'bookings']]) {
    app.get(`/${path}`, requireAuth, async (req, res) => {
      const data = await workflow(req.supabase, 'gymflow_read', 'history', page.parse(req.query));
      res.json(data[key]);
    });
  }
  app.get('/admin/dashboard', requireAuth, async (req, res) => {
    res.json(await workflow(req.supabase, 'gymflow_read', 'admin_dashboard', page.parse(req.query)));
  });
  app.get('/admin/members', requireAuth, async (req, res) => {
    const { limit, offset } = page.parse(req.query);
    const result = await req.supabase.rpc('gymflow_admin_members', {
      page_limit: limit,
      page_offset: offset,
    });
    if (result.error?.message === 'FORBIDDEN') throw new ApiError(403, 'FORBIDDEN', 'Chỉ quản trị viên được thực hiện thao tác này.');
    res.json(databaseResult(result));
  });
  app.post('/admin/members/:id/cancel-membership', requireAuth, async (req, res) => {
    const { reason } = z.object({ reason: z.string().trim().max(500).default('') })
      .strict().parse(req.body ?? {});
    const result = await req.supabase.rpc('gymflow_admin_cancel_membership', {
      target_user_id: uuid.parse(req.params.id),
      cancellation_reason: reason,
    });
    const known = businessErrors[result.error?.message];
    if (known) throw new ApiError(known[0], result.error.message, known[1]);
    res.json(databaseResult(result));
  });
  app.get('/admin/qr-current', requireAuth, async (req, res) => {
    const input = z.object({ gym_id: gymId.default('1') }).strict().parse(req.query);
    const result = await req.supabase.rpc('gymflow_current_qr', input);
    if (result.error?.message === 'FORBIDDEN') throw new ApiError(403, 'FORBIDDEN', 'Chỉ quản trị viên được xem QR tại quầy.');
    res.json(databaseResult(result));
  });
  app.post('/admin/qr-tokens', requireAuth, async (req, res) => {
    const input = z.object({ gym_id: gymId.default('1'), minutes: z.number().int().min(1).max(60).default(15) }).strict().parse(req.body);
    for (let attempt = 0; attempt < 3; attempt++) {
      const token = createQrToken();
      try {
        const record = await workflow(req.supabase, 'gymflow_command', 'admin_qr', { ...input, token_hash: await hashToken(token) });
        return res.status(201).json({ ...record, token });
      } catch (error) {
        // The only unique constraint in admin_qr is the token hash. Retry a collision.
        if (!(error instanceof ApiError) || error.code !== 'SLOT_UNAVAILABLE') throw error;
      }
    }
    throw new ApiError(503, 'QR_GENERATION_FAILED', 'Không thể tạo QR mới. Vui lòng thử lại.');
  });
  app.post('/admin/qr-tokens/:id/revoke', requireAuth, command('admin_revoke_qr', z.object({ id: uuid }).strict()));
  app.post('/admin/membership-orders/:id/review', requireAuth, command('admin_order', z.object({ id: uuid, status: z.enum(['APPROVED', 'REJECTED']) }).strict()));
  app.post('/admin/redemptions/:id/fulfill', requireAuth, command('admin_fulfill', z.object({ id: uuid }).strict()));

  const commonFields = { name: z.string().trim().min(1).max(100), description: z.string().max(5000).default(''), is_active: z.boolean().default(true) };
  const imageUrl = z.union([z.literal(''), z.url().refine(value => /^https?:\/\//.test(value))]).default('');
  const catalogueSchemas = {
    rewards: z.object({ ...commonFields, points: z.number().int().positive().max(1000000), stock: z.number().int().min(0).max(1000000).default(0), image_url: imageUrl }).strict(),
    memberships: z.object({ ...commonFields, price_vnd: z.number().int().min(0).max(2147483647), duration_days: z.number().int().min(1).max(3650), points_per_checkin: z.literal(5).default(5) }).strict(),
    trainers: z.object({ ...commonFields, specialty: z.string().max(500).default(''), experience_years: z.number().int().min(0).max(100).default(0), image_url: imageUrl }).strict(),
  };
  async function catalogueWrite(req, table, changes, id = null) {
    const result = await req.supabase.rpc('gymflow_catalogue', { table_name: table, record_id: id, changes });
    if(result.error?.message === 'FORBIDDEN') throw new ApiError(403, 'FORBIDDEN', 'Chỉ quản trị viên được quản lý danh mục.');
    if(result.error?.message === 'NOT_FOUND') throw new ApiError(404, 'NOT_FOUND', 'Không tìm thấy dữ liệu.');
    if(result.error?.code === '23505') throw new ApiError(409, 'DUPLICATE_NAME', 'Tên danh mục đã tồn tại.');
    return databaseResult(result);
  }
  for (const [table, schema] of Object.entries(catalogueSchemas)) {
    app.get(`/admin/${table}`, requireAuth, async (req, res) => {
      const { limit, offset } = page.parse(req.query);
      const result = await req.supabase.rpc('gymflow_catalogue', { table_name: table, page_limit: limit, page_offset: offset });
      if(result.error?.message === 'FORBIDDEN') throw new ApiError(403, 'FORBIDDEN', 'Chỉ quản trị viên được quản lý danh mục.');
      res.json(databaseResult(result));
    });
    app.post(`/admin/${table}`, requireAuth, async (req, res) => res.status(201).json(await catalogueWrite(req, table, schema.parse(req.body))));
    app.patch(`/admin/${table}/:id`, requireAuth, async (req, res) => {
      const parsed = schema.partial().parse(req.body);
      // Zod defaults inside optional fields must not reset omitted PATCH fields.
      const changes = Object.fromEntries(Object.keys(req.body).map(key => [key, parsed[key]]));
      if(Object.keys(changes).length === 0) throw new ApiError(400,'INVALID_INPUT','Cần nhập nội dung cập nhật.');
      res.json(await catalogueWrite(req, table, changes, uuid.parse(req.params.id)));
    });
    app.delete(`/admin/${table}/:id`, requireAuth, async (req, res) => res.json(await catalogueWrite(req, table, { is_active: false }, uuid.parse(req.params.id))));
    app.post(`/admin/${table}/:id/archive`, requireAuth, async (req, res) => {
      z.object({}).strict().parse(req.body);
      res.json(await catalogueWrite(req, table, { is_active: false }, uuid.parse(req.params.id)));
    });
  }

  app.use((_req, _res, next) => next(new ApiError(404, 'NOT_FOUND', 'Endpoint chưa được triển khai.')));
  app.use((error, _req, res, _next) => {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ code: 'VALIDATION_ERROR', message: 'Dữ liệu gửi lên không hợp lệ.', fields: error.issues.map(i => i.path.join('.')) });
    }
    if (error.type === 'entity.parse.failed') return res.status(400).json({ code: 'INVALID_JSON', message: 'JSON không hợp lệ.' });
    if (error.type === 'entity.too.large') return res.status(413).json({ code: 'PAYLOAD_TOO_LARGE', message: 'Dữ liệu gửi lên quá lớn.' });
    res.status(error.status ?? 500).json({ code: error.code ?? 'INTERNAL_ERROR', message: error instanceof ApiError ? error.message : 'Có lỗi máy chủ. Vui lòng thử lại.' });
  });
  return app;
}

import { createClient } from 'npm:@supabase/supabase-js@2.117.3';

export function makeClientFactory(config) {
  // Each request has its own client. Auth calls must never share session state.
  return token => createClient(config.SUPABASE_URL, config.SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: token ? { headers: { Authorization: `Bearer ${token}` } } : {},
  });
}

// Supabase forwards URLs with the function name included in the path.
export function createEdgeApp(options) {
  const gateway = express();
  gateway.disable('x-powered-by');
  gateway.use('/gymflow-api', createApp(options));
  return gateway;
}

if (typeof Deno !== 'undefined') {
  const url = Deno.env.get('SUPABASE_URL');
  const namedKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') || '{}');
  const key = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') || namedKeys.default || Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Missing Supabase URL or publishable/anon key.');
  const gateway = createEdgeApp({
    createSupabase: makeClientFactory({ SUPABASE_URL: url, SUPABASE_PUBLISHABLE_KEY: key }),
    createServiceSupabase: serviceKey
      ? makeClientFactory({ SUPABASE_URL: url, SUPABASE_PUBLISHABLE_KEY: serviceKey })
      : null,
    paymentConfig: {
      bankId: Deno.env.get('PAYMENT_BANK_ID'),
      accountNo: Deno.env.get('PAYMENT_ACCOUNT_NO'),
      accountName: Deno.env.get('PAYMENT_ACCOUNT_NAME'),
      sepayApiKey: Deno.env.get('SEPAY_API_KEY'),
    },
    corsOrigins: '*',
    trustProxy: 1,
  });
  gateway.listen(8000);
}
