// GymBro Mobile prototype — shared icons, brand mark, seed data, UI atoms.
// Faithful to the Angular portal: inv-* tokens, blue primary, kg as stored unit.

// ─────────────────────────────────────────────────────────────
// Icon set (Lucide/PrimeNG-style strokes, currentColor)
// ─────────────────────────────────────────────────────────────
const ICONS = {
  play:        { fill: true, d: 'M6 4l14 8-14 8V4z' },
  pause:       { d: 'M7 4v16M17 4v16' },
  check:       { d: 'M5 12.5l5 5 9-11' },
  plus:        { d: 'M12 5v14M5 12h14' },
  minus:       { d: 'M5 12h14' },
  x:           { d: 'M6 6l12 12M18 6L6 18' },
  chevR:       { d: 'M9 5l7 7-7 7' },
  chevL:       { d: 'M15 5l-7 7 7 7' },
  chevD:       { d: 'M5 9l7 7 7-7' },
  chevU:       { d: 'M5 15l7-7 7 7' },
  clock:       { d: 'M12 7v5l3 2', extra: 'circle9' },
  layers:      { d: 'M12 3l9 5-9 5-9-5 9-5zM3 13l9 5 9-5' },
  bars:        { d: 'M5 20V10M12 20V4M19 20v-7' },
  trophy:      { d: 'M7 4h10v5a5 5 0 01-10 0V4zM5 5H3v2a3 3 0 003 3M19 5h2v2a3 3 0 01-3 3M9 18h6M10 18v-2M14 18v-2M8 21h8' },
  bolt:        { fill: true, d: 'M13 2L4 14h6l-1 8 9-12h-6l1-8z' },
  folder:      { d: 'M3 7a2 2 0 012-2h4l2 2h8a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2V7z' },
  search:      { d: 'M11 19a8 8 0 100-16 8 8 0 000 16zM21 21l-4.3-4.3' },
  calendar:    { d: 'M7 3v4M17 3v4M4 9h16M5 5h14a1 1 0 011 1v13a1 1 0 01-1 1H5a1 1 0 01-1-1V6a1 1 0 011-1z' },
  history:     { d: 'M3 12a9 9 0 109-9 9 9 0 00-7 3.3M3 4v4h4M12 8v4l3 2' },
  user:        { d: 'M12 12a4 4 0 100-8 4 4 0 000 8zM5 21a7 7 0 0114 0' },
  home:        { d: 'M4 11l8-7 8 7M6 10v9a1 1 0 001 1h10a1 1 0 001-1v-9' },
  dumbbell:    { d: 'M6 7v10M3 9v6M18 7v10M21 9v6M6 12h12' },
  flame:       { d: 'M12 3c3 4 5 6 5 9a5 5 0 01-10 0c0-1.5.7-2.8 1.6-3.8C9 9.5 11 8 12 3z' },
  arrowR:      { d: 'M5 12h14M13 6l6 6-6 6' },
  arrowL:      { d: 'M19 12H5M11 6l-6 6 6 6' },
  skip:        { d: 'M5 5l10 7-10 7V5zM19 5v14' },
  swap:        { d: 'M7 4L3 8l4 4M3 8h13M17 20l4-4-4-4M21 16H8' },
  more:        { d: 'M5 12h.01M12 12h.01M19 12h.01' },
  lock:        { d: 'M6 11V8a6 6 0 1112 0v3M5 11h14a1 1 0 011 1v7a1 1 0 01-1 1H5a1 1 0 01-1-1v-7a1 1 0 011-1z' },
  eye:         { d: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z', extra: 'circle3' },
  settings:    { d: 'M12 15a3 3 0 100-6 3 3 0 000 6zM19.4 13a1.7 1.7 0 00.3 1.9l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-2.9 1.2V21a2 2 0 01-4 0v-.1A1.7 1.7 0 005 19.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00-1.2-2.9H1a2 2 0 010-4h.1A1.7 1.7 0 002.7 5l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.9.3H10a1.7 1.7 0 001-1.6V1a2 2 0 014 0v.1a1.7 1.7 0 002.9 1.2l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.9V10a1.7 1.7 0 001.6 1H23a2 2 0 010 4h-.1a1.7 1.7 0 00-1.5 1z' },
  bell:        { d: 'M18 8a6 6 0 10-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 01-3.4 0' },
  target:      { d: 'M12 12m-2 0a2 2 0 104 0 2 2 0 10-4 0', extra: 'ring' },
  mail:        { d: 'M4 6h16a1 1 0 011 1v10a1 1 0 01-1 1H4a1 1 0 01-1-1V7a1 1 0 011-1zM3 7l9 6 9-6' },
  key:         { d: 'M15 7a4 4 0 11-3.4 6.1L7 18H4v-3l5.9-5.9A4 4 0 0115 7zM17 9h.01' },
  ticket:      { d: 'M4 8a2 2 0 012-2h12a2 2 0 012 2 2 2 0 000 4 2 2 0 010 4 2 2 0 01-2 2H6a2 2 0 01-2-2 2 2 0 000-4 2 2 0 010-4zM12 6v12' },
  flag:        { d: 'M5 21V4M5 4h11l-2 4 2 4H5' },
  plusCircle:  { d: 'M12 8v8M8 12h8', extra: 'circle10' },
  edit:        { d: 'M12 20h9M16.5 3.5a2 2 0 013 3L7 19l-4 1 1-4 12.5-12.5z' },
  star:        { fill: true, d: 'M12 3l2.9 6 6.1.9-4.5 4.3 1.1 6.1L12 17.8 6.4 20.3l1.1-6.1L3 9.9 9.1 9 12 3z' },
  copy:        { d: 'M9 9h10a1 1 0 011 1v10a1 1 0 01-1 1H9a1 1 0 01-1-1V10a1 1 0 011-1zM5 15H4a1 1 0 01-1-1V4a1 1 0 011-1h10a1 1 0 011 1v1' },
  share:       { d: 'M4 12v7a2 2 0 002 2h12a2 2 0 002-2v-7M16 6l-4-4-4 4M12 2v14' },
  refresh:     { d: 'M3 12a9 9 0 0115-6.7L21 8M21 4v4h-4M21 12a9 9 0 01-15 6.7L3 16M3 20v-4h4' },
  archive:     { d: 'M4 8h16v11a1 1 0 01-1 1H5a1 1 0 01-1-1V8zM3 4h18v4H3zM10 12h4' },
  trash:       { d: 'M4 7h16M9 7V5a1 1 0 011-1h4a1 1 0 011 1v2M6 7l1 13a1 1 0 001 1h8a1 1 0 001-1l1-13' },
  userPlus:    { d: 'M9 12a4 4 0 100-8 4 4 0 000 8zM3 21a6 6 0 0112 0M18 8v6M21 11h-6' },
  users:       { d: 'M9 12a4 4 0 100-8 4 4 0 000 8zM2 21a7 7 0 0114 0M16 4a4 4 0 010 8M19 21a7 7 0 00-4-6.3' },
  clipboard:   { d: 'M9 4h6a1 1 0 011 1v1H8V5a1 1 0 011-1zM8 6H6a1 1 0 00-1 1v13a1 1 0 001 1h12a1 1 0 001-1V7a1 1 0 00-1-1h-2' },
  sliders:     { d: 'M4 6h10M18 6h2M4 12h2M10 12h10M4 18h8M16 18h4M14 4v4M6 10v4M12 16v4' },
};

function Icon({ name, size = 20, color = 'currentColor', strokeWidth = 2, style = {} }) {
  const ic = ICONS[name] || ICONS.x;
  const extra = ic.extra;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      style={{ display: 'block', flexShrink: 0, ...style }} aria-hidden="true">
      {extra === 'circle9' && <circle cx="12" cy="12" r="9" stroke={color} strokeWidth={strokeWidth} />}
      {extra === 'circle10' && <circle cx="12" cy="12" r="9" stroke={color} strokeWidth={strokeWidth} />}
      {extra === 'circle3' && <circle cx="12" cy="12" r="3" stroke={color} strokeWidth={strokeWidth} />}
      {extra === 'ring' && <circle cx="12" cy="12" r="9" stroke={color} strokeWidth={strokeWidth} />}
      <path d={ic.d} stroke={ic.fill ? 'none' : color} fill={ic.fill ? color : 'none'}
        strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// GymBro brand mark — rounded blue tile, "GB" (matches portal .app-shell-brand-mark)
function BrandMark({ size = 40, radius = 12, glyph = false }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: radius, flexShrink: 0, position: 'relative',
      background: 'var(--gb-hero)', overflow: 'hidden',
      color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontWeight: 800, fontSize: size * 0.38, letterSpacing: '-0.02em',
      boxShadow: 'var(--gb-shadow-blue-sm), inset 0 1px 0 rgba(255,255,255,0.32)',
    }}>
      <span style={{ position: 'absolute', inset: 0, background: 'radial-gradient(120% 80% at 20% 0%, rgba(255,255,255,0.28), transparent 55%)' }} />
      {glyph
        ? <Icon name="dumbbell" size={size * 0.52} color="#fff" strokeWidth={2.4} style={{ position: 'relative' }} />
        : <span style={{ position: 'relative' }}>GB</span>}
    </div>
  );
}

// Premium avatar — gradient ring around initial
function Avatar({ initial, size = 40, ring = false }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0, position: 'relative',
      background: 'linear-gradient(150deg, #2f6bff, #1d4ed8)', color: '#fff',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontWeight: 800, fontSize: size * 0.42, letterSpacing: '-0.01em',
      boxShadow: ring ? '0 0 0 3px var(--gb-card), 0 0 0 5px rgba(59,130,246,0.35)' : 'var(--gb-shadow-blue-sm)',
    }}>
      <span style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: 'radial-gradient(120% 90% at 25% 0%, rgba(255,255,255,0.3), transparent 60%)' }} />
      <span style={{ position: 'relative' }}>{initial}</span>
    </div>
  );
}

function Eyebrow({ children, color = 'var(--inv-grey-400)', style = {} }) {
  return <div className="gb-eyebrow" style={{ color, ...style }}>{children}</div>;
}

// ─────────────────────────────────────────────────────────────
// Completion ring (matches portal app-completion-ring)
// ─────────────────────────────────────────────────────────────
function Ring({ value, total, size = 56, stroke = 6, color = 'var(--inv-primary-500)', track = 'var(--inv-grey-25)', gradient = null, children }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const pct = total > 0 ? Math.min(1, value / total) : 0;
  const gid = React.useMemo(() => 'rg' + Math.random().toString(36).slice(2, 8), []);
  const stroked = gradient ? `url(#${gid})` : color;
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        {gradient && (
          <defs>
            <linearGradient id={gid} x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor={gradient[0]} />
              <stop offset="100%" stopColor={gradient[1]} />
            </linearGradient>
          </defs>
        )}
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={stroked} strokeWidth={stroke}
          strokeDasharray={c} strokeDashoffset={c * (1 - pct)} strokeLinecap="round"
          style={{ transition: 'stroke-dashoffset .6s cubic-bezier(.4,0,.2,1)' }} />
      </svg>
      {children && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {children}
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Seed data — one trainee, mid-program. kg is the stored unit.
// ─────────────────────────────────────────────────────────────
const TODAY_WORKOUT = {
  name: 'Push Day',
  program: 'Hypertrophy Block A',
  day: 'Day A',
  week: 3,
  exercises: [
    { id: 'e1', name: 'Barbell Bench Press', muscle: 'Chest', equipment: 'Barbell', rest: 120,
      sets: [
        { type: 'warmup',  reps: 10, kg: 40 },
        { type: 'working', reps: 8,  kg: 60 },
        { type: 'working', reps: 8,  kg: 60 },
        { type: 'working', reps: 8,  kg: 60 },
      ] },
    { id: 'e2', name: 'Seated Overhead Press', muscle: 'Shoulders', equipment: 'Dumbbell', rest: 90,
      sets: [
        { type: 'working', reps: 10, kg: 22 },
        { type: 'working', reps: 10, kg: 22 },
        { type: 'working', reps: 10, kg: 22 },
      ] },
    { id: 'e3', name: 'Incline DB Press', muscle: 'Chest', equipment: 'Dumbbell', rest: 90,
      sets: [
        { type: 'working', reps: 12, kg: 20 },
        { type: 'working', reps: 12, kg: 20 },
        { type: 'working', reps: 12, kg: 20 },
      ] },
    { id: 'e4', name: 'Cable Fly', muscle: 'Chest', equipment: 'Machine', rest: 60,
      sets: [
        { type: 'working', reps: 15, kg: 12 },
        { type: 'working', reps: 15, kg: 12 },
        { type: 'working', reps: 15, kg: 12 },
      ] },
    { id: 'e5', name: 'Triceps Pushdown', muscle: 'Arms', equipment: 'Machine', rest: 60,
      sets: [
        { type: 'working', reps: 15, kg: 25 },
        { type: 'working', reps: 15, kg: 25 },
        { type: 'working', reps: 15, kg: 25 },
      ] },
  ],
};

// Exercise library for the "add exercise" picker (live session).
// `muscle` = muscle group, matching the portal's MUSCLE_GROUPS + epp muscle tabs.
const MUSCLE_GROUPS = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];
const EXERCISE_LIBRARY = [
  { name: 'Dumbbell Bench Press', muscle: 'Chest', equipment: 'Dumbbell', reps: 10, kg: 24 },
  { name: 'Pec Deck Fly', muscle: 'Chest', equipment: 'Machine', reps: 15, kg: 30 },
  { name: 'Incline Push-up', muscle: 'Chest', equipment: 'Bodyweight', reps: 15, kg: 0 },
  { name: 'Lat Pulldown', muscle: 'Back', equipment: 'Machine', reps: 12, kg: 45 },
  { name: 'Seated Cable Row', muscle: 'Back', equipment: 'Machine', reps: 12, kg: 50 },
  { name: 'Face Pull', muscle: 'Back', equipment: 'Machine', reps: 15, kg: 15 },
  { name: 'Goblet Squat', muscle: 'Legs', equipment: 'Dumbbell', reps: 12, kg: 24 },
  { name: 'Romanian Deadlift', muscle: 'Legs', equipment: 'Barbell', reps: 10, kg: 70 },
  { name: 'Leg Press', muscle: 'Legs', equipment: 'Machine', reps: 12, kg: 120 },
  { name: 'Lateral Raise', muscle: 'Shoulders', equipment: 'Dumbbell', reps: 15, kg: 8 },
  { name: 'Arnold Press', muscle: 'Shoulders', equipment: 'Dumbbell', reps: 10, kg: 18 },
  { name: 'EZ-Bar Curl', muscle: 'Arms', equipment: 'Barbell', reps: 10, kg: 25 },
  { name: 'Triceps Dip', muscle: 'Arms', equipment: 'Bodyweight', reps: 12, kg: 0 },
  { name: 'Close-Grip Bench', muscle: 'Arms', equipment: 'Barbell', reps: 8, kg: 50 },
  { name: 'Cable Crunch', muscle: 'Core', equipment: 'Machine', reps: 15, kg: 25 },
  { name: 'Hanging Leg Raise', muscle: 'Core', equipment: 'Bodyweight', reps: 12, kg: 0 },
];

// Substitute options offered in the live session
const SUBSTITUTES = {
  e1: [
    { name: 'Dumbbell Bench Press', muscle: 'Chest', equipment: 'Dumbbell' },
    { name: 'Machine Chest Press', muscle: 'Chest', equipment: 'Machine' },
    { name: 'Push-up (weighted)', muscle: 'Chest', equipment: 'Bodyweight' },
  ],
};

const WEEK_GROUPS = [
  {
    label: 'This week', source: 'Hypertrophy Block A · Wk 3', done: 3, goal: 4, prCount: 1, volumeKg: 10320,
    items: [
      { id: 's-now', name: 'Push Day', day: 'WED', source: 'plan', status: 'active',
        rel: 'In progress', dur: null, sets: 16, doneSets: 5, vol: null, rpe: null, pr: 0 },
      { id: 's1', name: 'Mobility Flow', day: 'WED', source: 'adhoc', status: 'done',
        rel: 'Today · 7:10am', dur: 1080, sets: 8, vol: 0, rpe: 4, pr: 0 },
      { id: 's2', name: 'Leg Day', day: 'TUE', source: 'plan', status: 'done',
        rel: 'Yesterday', dur: 3060, sets: 20, vol: 6100, rpe: 8, pr: 0 },
      { id: 's3', name: 'Pull Day', day: 'MON', source: 'plan', status: 'done',
        rel: 'Mon · 6:40pm', dur: 2520, sets: 18, vol: 4220, rpe: 7, pr: 1 },
    ],
  },
  {
    label: 'Last week', source: 'Hypertrophy Block A · Wk 2', done: 4, goal: 4, prCount: 1, volumeKg: 11350,
    items: [
      { id: 's4', name: 'Full Body', day: 'SAT', source: 'adhoc', status: 'done',
        rel: 'Sat', dur: 2400, sets: 14, vol: 3100, rpe: 6, pr: 0 },
      { id: 's5', name: 'Leg Day', day: 'THU', source: 'plan', status: 'abandoned',
        rel: 'Thu', dur: 1320, sets: 9, vol: 2000, rpe: null, pr: 0 },
      { id: 's6', name: 'Pull Day', day: 'TUE', source: 'plan', status: 'done',
        rel: 'Tue', dur: 2640, sets: 18, vol: 4350, rpe: 7, pr: 1 },
      { id: 's7', name: 'Push Day', day: 'MON', source: 'plan', status: 'done',
        rel: 'Mon', dur: 2280, sets: 16, vol: 3900, rpe: 7, pr: 0 },
    ],
  },
];

const THIS_WEEK = { done: 3, goal: 4, volumeKg: 10320, sets: 46 };

// Completed-session detail shown on the Session Detail screen (Monday's Pull Day)
const SESSION_DETAIL = {
  name: 'Pull Day', program: 'Hypertrophy Block A', day: 'Day B', week: 3,
  date: 'Monday, Jun 1', startedAt: '6:40pm', dur: 2520,
  totalSets: 18, volumeKg: 4220, rpe: 7, prCount: 1,
  exercises: [
    { name: 'Deadlift', muscle: 'Back', pr: true, sets: [
      { reps: 5, kg: 100 }, { reps: 5, kg: 100 }, { reps: 5, kg: 110 }, { reps: 3, kg: 120 } ] },
    { name: 'Weighted Pull-up', muscle: 'Back', pr: false, sets: [
      { reps: 8, kg: 10 }, { reps: 8, kg: 10 }, { reps: 6, kg: 10 } ] },
    { name: 'Barbell Row', muscle: 'Back', pr: false, sets: [
      { reps: 10, kg: 50 }, { reps: 10, kg: 50 }, { reps: 10, kg: 50 } ] },
    { name: 'Lat Pulldown', muscle: 'Back', pr: false, sets: [
      { reps: 12, kg: 45 }, { reps: 12, kg: 45 }, { reps: 12, kg: 40 } ] },
    { name: 'Face Pull', muscle: 'Shoulders', pr: false, sets: [
      { reps: 15, kg: 15 }, { reps: 15, kg: 15 }, { reps: 15, kg: 15 } ] },
  ],
};

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
function fmtDuration(sec) {
  if (sec == null) return '—';
  const m = Math.floor(sec / 60), s = sec % 60;
  if (m >= 60) { const h = Math.floor(m/60); return `${h}h ${m%60}m`; }
  return s === 0 ? `${m}m` : `${m}:${String(s).padStart(2,'0')}`;
}
function fmtClock(sec) {
  const m = Math.floor(sec / 60), s = sec % 60;
  return `${m}:${String(s).padStart(2,'0')}`;
}
function fmtVolume(kg) {
  if (kg == null) return '—';
  return kg >= 1000 ? (kg/1000).toFixed(1).replace(/\.0$/,'') + 'k' : String(kg);
}
const SET_TYPE_LABEL = { warmup: 'Warm-up', working: 'Working', drop: 'Drop', amrap: 'AMRAP' };

Object.assign(window, {
  Icon, BrandMark, Ring, Avatar, Eyebrow,
  TODAY_WORKOUT, SUBSTITUTES, EXERCISE_LIBRARY, MUSCLE_GROUPS, WEEK_GROUPS, THIS_WEEK, SESSION_DETAIL,
  fmtDuration, fmtClock, fmtVolume, SET_TYPE_LABEL,
});
