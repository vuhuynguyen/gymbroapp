// GymBro Mobile — Coach (Owner) seed data. Mirrors business rules:
// 8-char invite codes (no 0/O/1/I), 7-day expiry, single-use, always Client;
// plans are immutable version chains (TemplateId + Version); assignments pin a
// version with visibility modes (Full/Guided/Blind) + hide flags.

const COACH = { name: 'Morgan Hale', initial: 'M', workspace: 'Hale Strength', clients: 6, plans: 4 };

const CLIENTS = [
  { id: 'c1', name: 'Alex Rivera', initial: 'A', plan: 'Hypertrophy Block A', visibility: 'Full',
    done: 3, goal: 4, last: '2h ago', volumeKg: 10320, streak: 5, status: 'active', flag: 'on-track' },
  { id: 'c2', name: 'Priya Nair', initial: 'P', plan: 'Hypertrophy Block A', visibility: 'Guided',
    done: 4, goal: 4, last: 'Yesterday', volumeKg: 12650, streak: 12, status: 'active', flag: 'on-track' },
  { id: 'c3', name: 'Sam Okafor', initial: 'S', plan: 'Strength 5×5', visibility: 'Full',
    done: 1, goal: 3, last: '4 days ago', volumeKg: 4200, streak: 0, status: 'active', flag: 'behind' },
  { id: 'c4', name: 'Lena Fischer', initial: 'L', plan: 'Fat Loss Circuit', visibility: 'Guided',
    done: 2, goal: 3, last: 'Today', volumeKg: 3850, streak: 3, status: 'active', flag: 'on-track' },
  { id: 'c5', name: 'Diego Santos', initial: 'D', plan: '— no active plan', visibility: '—',
    done: 0, goal: 0, last: '2 weeks ago', volumeKg: 0, streak: 0, status: 'idle', flag: 'unassigned' },
  { id: 'c6', name: 'Mia Chen', initial: 'M', plan: 'Strength 5×5', visibility: 'Blind',
    done: 3, goal: 3, last: 'Today', volumeKg: 9100, streak: 8, status: 'active', flag: 'on-track' },
];

const COACH_PLANS = [
  { id: 'p1', templateId: 't1', name: 'Hypertrophy Block A', version: 3, workouts: 4, daysPerWeek: 4,
    durationWeeks: 8, assigned: 2, archived: false, updated: '3 days ago' },
  { id: 'p2', templateId: 't2', name: 'Strength 5×5', version: 1, workouts: 3, daysPerWeek: 3,
    durationWeeks: 12, assigned: 2, archived: false, updated: '2 weeks ago' },
  { id: 'p3', templateId: 't3', name: 'Fat Loss Circuit', version: 2, workouts: 3, daysPerWeek: 3,
    durationWeeks: 6, assigned: 1, archived: false, updated: '5 days ago' },
  { id: 'p4', templateId: 't4', name: 'Deload Week', version: 1, workouts: 2, daysPerWeek: 2,
    durationWeeks: 1, assigned: 0, archived: true, updated: '1 month ago' },
];

// Editable plan structure for the builder (workouts → exercises → prescribed sets).
// Set types: Warmup | Working | Drop | Amrap. Weights in kg.
const PLAN_DETAIL = {
  id: 'p1', name: 'Hypertrophy Block A', version: 3, durationWeeks: 8, daysPerWeek: 4,
  workouts: [
    { id: 'w1', name: 'Push Day', exercises: [
      { id: 'pe1', name: 'Barbell Bench Press', muscle: 'Chest', sets: [
        { type: 'warmup', reps: 10, kg: 40, rpe: null, rest: 90 },
        { type: 'working', reps: 8, kg: 60, rpe: 8, rest: 120 },
        { type: 'working', reps: 8, kg: 60, rpe: 8, rest: 120 },
        { type: 'working', reps: 8, kg: 60, rpe: 9, rest: 120 },
      ] },
      { id: 'pe2', name: 'Seated Overhead Press', muscle: 'Shoulders', sets: [
        { type: 'working', reps: 10, kg: 22, rpe: 8, rest: 90 },
        { type: 'working', reps: 10, kg: 22, rpe: 8, rest: 90 },
        { type: 'working', reps: 10, kg: 22, rpe: 9, rest: 90 },
      ] },
      { id: 'pe3', name: 'Cable Fly', muscle: 'Chest', sets: [
        { type: 'working', reps: 15, kg: 12, rpe: 8, rest: 60 },
        { type: 'drop', reps: 15, kg: 8, rpe: 10, rest: 60 },
      ] },
    ] },
    { id: 'w2', name: 'Pull Day', exercises: [
      { id: 'pe4', name: 'Deadlift', muscle: 'Back', sets: [
        { type: 'warmup', reps: 5, kg: 60, rpe: null, rest: 120 },
        { type: 'working', reps: 5, kg: 100, rpe: 8, rest: 180 },
        { type: 'working', reps: 5, kg: 110, rpe: 9, rest: 180 },
      ] },
      { id: 'pe5', name: 'Lat Pulldown', muscle: 'Back', sets: [
        { type: 'working', reps: 12, kg: 45, rpe: 8, rest: 90 },
        { type: 'working', reps: 12, kg: 45, rpe: 8, rest: 90 },
        { type: 'amrap', reps: 12, kg: 40, rpe: 10, rest: 90 },
      ] },
    ] },
    { id: 'w3', name: 'Leg Day', exercises: [
      { id: 'pe6', name: 'Back Squat', muscle: 'Legs', sets: [
        { type: 'working', reps: 8, kg: 80, rpe: 8, rest: 150 },
        { type: 'working', reps: 8, kg: 80, rpe: 9, rest: 150 },
      ] },
    ] },
    { id: 'w4', name: 'Accessories', exercises: [
      { id: 'pe7', name: 'Cable Crunch', muscle: 'Core', sets: [
        { type: 'working', reps: 15, kg: 25, rpe: 8, rest: 60 },
      ] },
    ] },
  ],
};

// Active invites the coach has minted (8 chars, alphabet excludes 0/O/1/I).
const INVITES = [
  { code: 'K7P2WX9M', created: '2 days ago', expires: 'in 5 days', email: null },
  { code: 'R4HJ8NQ3', created: '5 days ago', expires: 'in 2 days', email: 'diego@mail.com' },
];

const VISIBILITY_MODES = [
  { id: 'Full', label: 'Full', desc: 'Trainee sees the whole plan and prescriptions.' },
  { id: 'Guided', label: 'Guided', desc: 'Filtered by the hide flags below — coach controls what shows.' },
  { id: 'Blind', label: 'Blind', desc: 'No snapshot at session start — exercises aren\u2019t seeded.' },
];

const HIDE_FLAGS = [
  { id: 'hideSetsReps', label: 'Hide sets & reps', desc: 'Trainee logs their own sets, guided live.' },
  { id: 'hideExercises', label: 'Hide exercises', desc: 'Strips names in the plan preview only.' },
  { id: 'hideFutureWorkouts', label: 'Hide future workouts', desc: 'Preview shows only the current week.' },
  { id: 'disableTraineeEditing', label: 'Lock structure', desc: 'Blocks add / skip / substitute in-session.' },
];

// A trainee's active assignments (they pick one at workout start — no auto-select).
const MY_ASSIGNMENTS = [
  { id: 'a1', plan: 'Hypertrophy Block A', coach: 'Coach Morgan', day: 'Push Day · Day A',
    week: 3, freq: 4, visibility: 'Full', exercises: 5, sets: 16 },
  { id: 'a2', plan: 'Conditioning Add-on', coach: 'Coach Morgan', day: 'Intervals',
    week: 3, freq: 2, visibility: 'Guided', exercises: 4, sets: 10 },
];

// Epley estimated 1RM — working sets only, rounded to 0.1 (business rule)
function e1rm(kg, reps) {
  if (!kg || !reps) return null;
  return Math.round(kg * (1 + reps / 30) * 10) / 10;
}

Object.assign(window, {
  COACH, CLIENTS, COACH_PLANS, PLAN_DETAIL, INVITES, VISIBILITY_MODES, HIDE_FLAGS, MY_ASSIGNMENTS, e1rm,
});
