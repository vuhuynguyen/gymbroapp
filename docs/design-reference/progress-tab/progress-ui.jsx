// GymBro Progress — primitives. Premium fitness aesthetic on the brand
// blue: instrument-grade typography, refined materials, a brand keyline
// signature, and elegant small-scale charts. Exposed on window.

const ICONS = {
  check:    { d: 'M5 12.5l5 5 9-11' },
  plus:     { d: 'M12 5v14M5 12h14' },
  chevR:    { d: 'M9 6l6 6-6 6' },
  bell:     { d: 'M18 8a6 6 0 10-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 01-3.4 0' },
  trophy:   { d: 'M7 4h10v5a5 5 0 01-10 0V4zM5 5H3v2a3 3 0 003 3M19 5h2v2a3 3 0 01-3 3M9 18h6M10 18v-2M14 18v-2M8 21h8' },
  flame:    { d: 'M12 3c3 4 5 6 5 9a5 5 0 01-10 0c0-1.5.7-2.8 1.6-3.8C9 9.5 11 8 12 3z' },
  refresh:  { d: 'M3 12a9 9 0 0115-6.7L21 8M21 4v4h-4M21 12a9 9 0 01-15 6.7L3 16M3 20v-4h4' },
  dumbbell: { d: 'M6.5 7v10M3.5 9.5v5M17.5 7v10M20.5 9.5v5M6.5 12h11' },
  cloudOff: { d: 'M3 3l18 18M18.4 16.5A4 4 0 0017 9h-1.3a7 7 0 00-9-3.4M5 9a4 4 0 00-1 7.9h11' },
  calendar: { d: 'M7 3v4M17 3v4M4 9h16M5 5h14a1 1 0 011 1v13a1 1 0 01-1 1H5a1 1 0 01-1-1V6a1 1 0 011-1z' },
  user:     { d: 'M12 12a4 4 0 100-8 4 4 0 000 8zM5 20.5a7 7 0 0114 0' },
  users:    { d: 'M9 12a4 4 0 100-8 4 4 0 000 8zM2.5 20.5a6.5 6.5 0 0113 0M16 4a4 4 0 010 8M21.5 20.5a6.5 6.5 0 00-4-6' },
  history:  { d: 'M3 12a9 9 0 109-9 9 9 0 00-7 3.3M3 4v4h4M12 8v4l3 2' },
  chart:    { d: 'M4 20h16M7.5 20V11M12 20V5M16.5 20v-6' },
  scale:    { d: 'M4 7h16l-2.4 9a2 2 0 01-1.9 1.5H8.3a2 2 0 01-1.9-1.5L4 7zM9 7a3 3 0 016 0' },
  chevL:    { d: 'M15 6l-6 6 6 6' },
  search:   { d: 'M11 18a7 7 0 100-14 7 7 0 000 14zM20 20l-3.6-3.6' },
  sliders:  { d: 'M4 8h9M17 8h3M4 16h3M11 16h9M13 6v4M9 14v4' },
  more:     { d: 'M5 12h.01M12 12h.01M19 12h.01' },
  clock:    { d: 'M12 7v5l3 2M12 21a9 9 0 100-18 9 9 0 000 18z' },
  message:  { d: 'M21 12a8 8 0 01-11.5 7.2L4 20l1.3-4A8 8 0 1121 12z' },
  lock:     { d: 'M7 11V8a5 5 0 0110 0v3M6 11h12a1 1 0 011 1v7a1 1 0 01-1 1H6a1 1 0 01-1-1v-7a1 1 0 011-1z' },
  camera:   { d: 'M4 8h3l1.5-2h7L17 8h3a1 1 0 011 1v9a1 1 0 01-1 1H4a1 1 0 01-1-1V9a1 1 0 011-1zM12 16a3 3 0 100-6 3 3 0 000 6z' },
  ruler:    { d: 'M5 11l8-8 6 6-8 8zM8 8l2 2M11 5l2 2M5 11l-2 2 6 6 2-2' },
  x:        { d: 'M6 6l12 12M18 6L6 18' },
  medal:    { d: 'M8 3l4 6 4-6M9.5 7.5L7 3M14.5 7.5L17 3M12 21a5 5 0 100-10 5 5 0 000 10zM12 13.5l.8 1.6 1.7.2-1.2 1.2.3 1.7-1.6-.9-1.6.9.3-1.7-1.2-1.2 1.7-.2z' },
  target:   { d: 'M12 21a9 9 0 100-18 9 9 0 000 18zM12 16a4 4 0 100-8 4 4 0 000 8zM12 13a1 1 0 100-2 1 1 0 000 2z' },
  arrowR:   { d: 'M5 12h14M13 6l6 6-6 6' },
  check2:   { d: 'M5 12.5l5 5 9-11' },
  bolt:     { d: 'M13 3L5 13h5l-1 8 8-10h-5l1-8z' },
};
function Icon({ name, size = 20, color = 'currentColor', strokeWidth = 1.75, style = {} }) {
  const ic = ICONS[name] || ICONS.check;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      style={{ display: 'block', flexShrink: 0, ...style }} aria-hidden="true">
      <path d={ic.d} stroke={color} fill="none" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// Brand mark — solid brand square, white glyph
function BrandMark({ size = 34, radius = 10 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: radius, flexShrink: 0,
      background: 'var(--brand-grad)', color: 'var(--btn-fg)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      boxShadow: '0 2px 6px -2px rgba(37,99,235,0.5), inset 0 1px 0 rgba(255,255,255,0.25)',
    }}>
      <Icon name="dumbbell" size={size * 0.56} color="var(--btn-fg)" strokeWidth={2} />
    </div>
  );
}

// Mono uppercase micro-label
function Eyebrow({ children, color, style = {} }) {
  return <div className="gb-label" style={{ ...(color ? { color } : {}), ...style }}>{children}</div>;
}

// Section header — brand keyline + label + hairline rule + action.
// The blue keyline is GymBro's recurring signature down the page.
function SectionTitle({ children, right }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '0 2px' }}>
      <span style={{ width: 3, height: 13, borderRadius: 2, background: 'var(--brand)', flexShrink: 0 }} />
      <span style={{ fontSize: 12.5, fontWeight: 800, color: 'var(--ink)', letterSpacing: '0.05em', textTransform: 'uppercase' }}>{children}</span>
      <span style={{ flex: 1, height: 1, background: 'var(--line)' }} />
      {right}
    </div>
  );
}

// Surface card. tier 1/2 = elevated, 3 = recessed/supporting.
function Card({ children, tier = 2, pad = 16, style = {}, className = '', ...rest }) {
  const cls = tier === 3 ? 'surf-quiet' : 'surf';
  return <div className={`${cls} ${className}`} style={{ padding: pad, flexShrink: 0, ...style }} {...rest}>{children}</div>;
}

// Icon tile — consistent radius/border, optically centered glyph
function IconTile({ name, size = 40, ink = 'var(--ink2)', iconSize, bg = 'var(--card2)', border = 'var(--line)' }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 11, flexShrink: 0, background: bg, border: `1px solid ${border}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.5)',
    }}>
      <Icon name={name} size={iconSize || Math.round(size * 0.46)} color={ink} strokeWidth={1.75} />
    </div>
  );
}

function CountUp({ to, decimals = 0, suffix = '', prefix = '' }) {
  return <>{prefix}{Number(to).toFixed(decimals)}{suffix}</>;
}

// ── Ring — clean stroke, subtle track, round cap, CSS-var sweep ──
function Ring({ value, total, size = 78, stroke = 7, color = 'var(--brand)', track = 'var(--line)', children }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const target = total > 0 ? Math.min(1, value / total) : 0;
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
        <circle className="gb-ring-prog" cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeWidth={stroke}
          strokeDasharray={c} strokeDashoffset={c * (1 - target)} strokeLinecap="round"
          style={{ '--ring-c': c + 'px' }} />
      </svg>
      {children && <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{children}</div>}
    </div>
  );
}

// ── Direction tick — caret glyph + mono delta; color on text only ──
const DIR = { up: 'var(--pos)', flat: 'var(--warn)', down: 'var(--neg)' };
function Caret({ dir, color }) {
  if (dir === 'flat') return <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2.5 6h7" stroke={color} strokeWidth="2" strokeLinecap="round" /></svg>;
  const up = dir === 'up';
  return <svg width="12" height="12" viewBox="0 0 12 12"><path d={up ? 'M6 2.5l4 5.5H2z' : 'M6 9.5l4-5.5H2z'} fill={color} /></svg>;
}
function DirTag({ dir, label }) {
  const col = DIR[dir];
  return (
    <span className="gb-mono" style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: col, fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap', textTransform: 'uppercase', letterSpacing: '0.01em' }}>
      <Caret dir={dir} color={col} />{label}
    </span>
  );
}

// ── Sparkline — refined stroke, subtle fill, crisp donut endpoint ──
function smoothPath(pts) {
  if (pts.length < 3) return pts.map((p, i) => (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' ');
  let d = `M${pts[0][0].toFixed(1)} ${pts[0][1].toFixed(1)}`;
  const t = 0.17;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || pts[i + 1];
    const c1x = p1[0] + (p2[0] - p0[0]) * t, c1y = p1[1] + (p2[1] - p0[1]) * t;
    const c2x = p2[0] - (p3[0] - p1[0]) * t, c2y = p2[1] - (p3[1] - p1[1]) * t;
    d += `C${c1x.toFixed(1)} ${c1y.toFixed(1)} ${c2x.toFixed(1)} ${c2y.toFixed(1)} ${p2[0].toFixed(1)} ${p2[1].toFixed(1)}`;
  }
  return d;
}
function Sparkline({ data, dir = 'up', width = 92, height = 38, dotsOnly = false }) {
  const col = DIR[dir];
  const min = Math.min(...data), max = Math.max(...data);
  const span = max - min || 1;
  const padY = 6, padX = 4;
  const xs = i => padX + (i / (data.length - 1)) * (width - padX - 7);
  const ys = v => height - padY - ((v - min) / span) * (height - padY * 2);
  const pts = data.map((v, i) => [xs(i), ys(v)]);
  if (dotsOnly) {
    return (
      <svg width={width} height={height} style={{ display: 'block', flexShrink: 0 }}>
        {pts.map((p, i) => <circle key={i} cx={p[0]} cy={p[1]} r="2.3" fill="none" stroke="var(--ink4)" strokeWidth="1.4" />)}
      </svg>
    );
  }
  const path = smoothPath(pts);
  const last = pts[pts.length - 1];
  const gid = React.useMemo(() => 'sp' + Math.random().toString(36).slice(2, 7), []);
  return (
    <svg width={width} height={height} style={{ display: 'block', flexShrink: 0, overflow: 'visible' }}>
      <defs>
        <linearGradient id={gid} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0%" stopColor={col} stopOpacity="0" />
          <stop offset="100%" stopColor={col} stopOpacity="0.12" />
        </linearGradient>
      </defs>
      <path className="gb-spark-fill" d={`${path} L ${last[0].toFixed(1)} ${height} L ${pts[0][0].toFixed(1)} ${height} Z`} fill={`url(#${gid})`} />
      <path className="gb-spark-path" pathLength="1" d={path} fill="none" stroke={col} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      <circle className="gb-spark-dot" cx={last[0]} cy={last[1]} r="4.4" fill={col} opacity="0.16" />
      <circle className="gb-spark-dot" cx={last[0]} cy={last[1]} r="2.5" fill="var(--card)" stroke={col} strokeWidth="2" />
    </svg>
  );
}

// ── Consistency heatmap — single-hue brand-blue ramp, crisp cells ──
const HEAT = ['var(--heat0)', 'var(--heat1)', 'var(--heat2)', 'var(--heat3)', 'var(--heat4)'];
function Heatmap({ weeks, gap = 4.5 }) {
  const dayLabels = ['M', '', 'W', '', 'F', '', ''];
  return (
    <div style={{ display: 'flex', gap: 7 }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap, paddingTop: 1 }}>
        {dayLabels.map((l, i) => (
          <div key={i} className="gb-mono" style={{ height: 14, width: 8, fontSize: 8.5, fontWeight: 600, color: 'var(--ink4)', display: 'flex', alignItems: 'center', lineHeight: 1 }}>{l}</div>
        ))}
      </div>
      <div style={{ display: 'flex', gap, flex: 1 }}>
        {weeks.map((wk, wi) => (
          <div key={wi} style={{ display: 'flex', flexDirection: 'column', gap, flex: 1 }}>
            {wk.map((v, di) => (
              <div key={di} className="gb-heat-cell" style={{
                width: '100%', aspectRatio: '1 / 1', borderRadius: 3,
                background: v == null ? 'transparent' : HEAT[v],
                outline: v == null ? '1px dashed var(--line)' : 'none', outlineOffset: -1,
                boxShadow: v >= 1 ? 'inset 0 0 0 1px rgba(255,255,255,0.10)' : 'none',
                animationDelay: (wi * 26 + di * 5) + 'ms',
              }} />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
function HeatLegend() {
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
      <span className="gb-label" style={{ fontSize: 8.5, color: 'var(--ink4)' }}>Less</span>
      {HEAT.map((c, i) => <span key={i} style={{ width: 10, height: 10, borderRadius: 2.5, background: c }} />)}
      <span className="gb-label" style={{ fontSize: 8.5, color: 'var(--ink4)' }}>More</span>
    </div>
  );
}

Object.assign(window, {
  Icon, BrandMark, Eyebrow, SectionTitle, Card, IconTile, Ring, DirTag, Sparkline, Heatmap, HeatLegend, CountUp,
});
