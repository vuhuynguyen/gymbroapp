// GymBro Mobile — shared UI atoms (platform-aware). Mirror the portal's
// shared/ui wrappers (app-button, app-input, dialogs → bottom sheets).

// Top inset to clear the iOS status bar / dynamic island; Android status bar is in flow.
function safeTop(platform) { return platform === 'ios' ? 54 : 10; }
function bottomInset(platform) { return platform === 'ios' ? 22 : 8; }

// ── Button (mirrors app-button) ───────────────────────────────
function GbButton({ label, icon, iconRight, onClick, severity = 'primary',
  outlined = false, text = false, full = false, size = 'md', disabled = false, style = {} }) {
  const [press, setPress] = React.useState(false);
  const h = size === 'lg' ? 54 : size === 'sm' ? 38 : 48;
  const fs = size === 'lg' ? 16.5 : size === 'sm' ? 13 : 15;
  let bg = 'var(--gb-hero)', col = '#fff', border = 'transparent';
  if (severity === 'secondary') { bg = 'var(--inv-surface-base)'; col = 'var(--inv-grey-700)'; border = 'var(--inv-grey-50)'; }
  if (severity === 'danger') { bg = 'var(--inv-error-100)'; col = '#fff'; }
  if (outlined) { bg = 'transparent'; col = severity === 'primary' ? 'var(--inv-primary-600)' : 'var(--inv-grey-700)'; border = severity === 'primary' ? 'var(--inv-primary-200)' : 'var(--inv-grey-50)'; }
  if (text) { bg = 'transparent'; border = 'transparent'; col = severity === 'danger' ? 'var(--inv-error-100)' : severity === 'secondary' ? 'var(--inv-grey-600)' : 'var(--inv-primary-600)'; }
  return (
    <button onClick={disabled ? undefined : onClick}
      onMouseDown={() => setPress(true)} onMouseUp={() => setPress(false)} onMouseLeave={() => setPress(false)}
      disabled={disabled}
      style={{
        height: h, width: full ? '100%' : undefined, border: `1.5px solid ${border}`,
        background: bg, color: col, borderRadius: 'var(--gb-r-sm)', padding: '0 18px', cursor: disabled ? 'default' : 'pointer',
        font: `700 ${fs}px/1 var(--inv-font-sans)`, letterSpacing: '-0.01em', whiteSpace: 'nowrap', display: 'inline-flex', alignItems: 'center',
        justifyContent: 'center', gap: 8, opacity: disabled ? 0.45 : 1,
        transform: press ? 'scale(0.975)' : 'scale(1)', transition: 'transform .12s, filter .12s',
        filter: press ? 'brightness(0.95)' : 'none',
        boxShadow: (severity === 'primary' && !outlined && !text) ? 'var(--gb-shadow-blue-sm)' : 'none',
        ...style,
      }}>
      {icon && <Icon name={icon} size={fs + 3} />}
      <span>{label}</span>
      {iconRight && <Icon name={iconRight} size={fs + 3} />}
    </button>
  );
}

// ── Text field (mirrors app-input) ────────────────────────────
function Field({ label, value, placeholder, icon, type = 'text', onFocus, trailing, focused = false }) {
  return (
    <label style={{ display: 'block' }}>
      {label && <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--inv-grey-700)', marginBottom: 6 }}>{label}</div>}
      <div onClick={onFocus} style={{
        height: 50, display: 'flex', alignItems: 'center', gap: 10, padding: '0 14px',
        background: 'var(--inv-surface-base)', borderRadius: 'var(--gb-r-sm)',
        border: `1.5px solid ${focused ? 'var(--inv-primary-400)' : 'var(--inv-border-field)'}`,
        boxShadow: focused ? '0 0 0 4px rgba(59,130,246,0.14)' : 'var(--gb-shadow-sm)', transition: 'border .15s, box-shadow .15s',
      }}>
        {icon && <Icon name={icon} size={18} color="var(--inv-grey-400)" />}
        <span style={{ flex: 1, fontSize: 15, color: value ? 'var(--inv-grey-900)' : 'var(--inv-grey-400)' }}>
          {type === 'password' && value ? '•'.repeat(value.length) : (value || placeholder)}
        </span>
        {focused && <span style={{ width: 2, height: 20, background: 'var(--inv-primary-500)', animation: 'gbCaret 1s steps(1) infinite' }} />}
        {trailing}
      </div>
    </label>
  );
}

// ── Bottom tab bar (platform-adaptive) ────────────────────────
function TabBar({ tabs, active, onChange, platform }) {
  const ios = platform === 'ios';
  return (
    <div style={{
      flexShrink: 0,
      paddingBottom: bottomInset(platform),
      background: ios ? 'rgba(255,255,255,0.82)' : 'var(--inv-surface-base)',
      backdropFilter: ios ? 'blur(18px) saturate(180%)' : 'none',
      WebkitBackdropFilter: ios ? 'blur(18px) saturate(180%)' : 'none',
      borderTop: '1px solid var(--inv-border-card)',
    }}>
      <div style={{ display: 'flex', height: ios ? 56 : 62 }}>
        {tabs.map(t => {
          const on = active === t.id;
          return (
            <button key={t.id} onClick={() => onChange(t.id)} style={{
              flex: 1, border: 'none', background: 'none', cursor: 'pointer',
              display: 'flex', flexDirection: 'column', alignItems: 'center',
              justifyContent: 'center', gap: ios ? 4 : 5, paddingTop: ios ? 0 : 8,
            }}>
              <div style={{
                position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center',
                width: ios ? 'auto' : 56, height: ios ? 'auto' : 30,
                borderRadius: 999,
                background: (!ios && on) ? 'var(--inv-primary-25)' : 'transparent',
                transition: 'background .2s',
              }}>
                <Icon name={t.icon} size={ios ? 24 : 22} strokeWidth={on ? 2.4 : 2}
                  color={on ? 'var(--inv-primary-600)' : 'var(--inv-grey-400)'} />
              </div>
              <span style={{
                fontSize: ios ? 10.5 : 12, fontWeight: on ? 700 : 500,
                color: on ? 'var(--inv-primary-600)' : 'var(--inv-grey-500)',
              }}>{t.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ── Bottom sheet (mirrors dialogs, mobile-native) ─────────────
function BottomSheet({ open, onClose, children, height = 'auto' }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 80, pointerEvents: open ? 'auto' : 'none',
    }}>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, background: 'rgba(11,18,32,0.45)',
        backdropFilter: 'blur(2px)', opacity: open ? 1 : 0, transition: 'opacity .25s',
      }} />
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: 'var(--inv-surface-base)', borderRadius: '22px 22px 0 0',
        boxShadow: '0 -8px 30px rgba(0,0,0,0.18)', height,
        transform: open ? 'translateY(0)' : 'translateY(110%)',
        transition: 'transform .32s cubic-bezier(.32,.72,0,1)',
        padding: '10px 0 0', display: 'flex', flexDirection: 'column',
      }}>
        <div style={{ width: 38, height: 4, borderRadius: 2, background: 'var(--inv-grey-50)', margin: '0 auto 6px' }} />
        {children}
      </div>
    </div>
  );
}

// ── Small bits ────────────────────────────────────────────────
function SourceTag({ source, small }) {
  const adhoc = source === 'adhoc';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4, borderRadius: 4,
      padding: small ? '1px 6px' : '2px 7px', fontSize: small ? 10 : 11, fontWeight: 600,
      background: adhoc ? 'var(--inv-warning-0)' : 'var(--inv-primary-0)',
      color: adhoc ? 'var(--inv-warning-300)' : 'var(--inv-primary-700)',
    }}>
      <Icon name={adhoc ? 'bolt' : 'folder'} size={small ? 10 : 12} />
      {adhoc ? 'Ad-hoc' : 'Plan'}
    </span>
  );
}

function PRChip({ small }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4, borderRadius: 999,
      padding: small ? '2px 8px' : '3px 10px', fontSize: small ? 10 : 11, fontWeight: 800, letterSpacing: '0.02em',
      background: 'var(--gb-amber-soft)', color: 'var(--gb-amber-ink)',
    }}>
      <Icon name="trophy" size={small ? 11 : 13} color="var(--gb-amber)" /> PR
    </span>
  );
}

const DAY_BADGE_COLORS = {
  active:    ['var(--inv-primary-0)', 'var(--inv-primary-700)'],
  done:      ['var(--inv-grey-25)', 'var(--inv-grey-700)'],
  abandoned: ['var(--inv-error-0)', 'var(--inv-error-200)'],
};
function DayBadge({ day, status }) {
  const [bg, fg] = DAY_BADGE_COLORS[status] || DAY_BADGE_COLORS.done;
  return (
    <div style={{
      width: 44, height: 44, borderRadius: 13, background: bg, color: fg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: 12, fontWeight: 800, letterSpacing: '0.04em', flexShrink: 0,
    }}>{day}</div>
  );
}

Object.assign(window, {
  safeTop, bottomInset, GbButton, Field, TabBar, BottomSheet, SourceTag, PRChip, DayBadge, GbSwitch,
});

// ── Switch (platform-adaptive) ────────────────────────────────
function GbSwitch({ on, onChange, platform }) {
  const ios = platform === 'ios';
  return (
    <button onClick={() => onChange(!on)} style={{
      width: ios ? 50 : 44, height: ios ? 30 : 26, borderRadius: 999, border: 'none', cursor: 'pointer',
      padding: 2, flexShrink: 0, position: 'relative', transition: 'background .2s',
      background: on ? 'var(--inv-primary-500)' : 'var(--inv-grey-50)',
    }}>
      <span style={{
        display: 'block', width: ios ? 26 : 20, height: ios ? 26 : 20, borderRadius: '50%', background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,0.3)', transition: 'transform .2s',
        transform: on ? `translateX(${ios ? 20 : 18}px)` : 'translateX(0)',
      }} />
    </button>
  );
}
