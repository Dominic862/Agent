import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { format, addMonths, startOfMonth } from 'date-fns'

const generateMonths = (startDate, endDate) => {
  const months = []
  let current = startOfMonth(new Date(startDate))
  const end = startOfMonth(new Date(endDate))
  while (current <= end) {
    months.push(format(current, 'yyyy-MM'))
    current = addMonths(current, 1)
  }
  return months
}

export const useStore = create(
  persist(
    (set, get) => ({
      // ─── Project ──────────────────────────────────────────────
      project: {
        name: '',
        currency: 'CHF',
        startDate: format(new Date(), 'yyyy-MM-dd'),
        endDate: format(addMonths(new Date(), 11), 'yyyy-MM-dd'),
        totalBudget: 0,
      },
      setProject: (data) => set({ project: { ...get().project, ...data } }),

      // ─── Monthly Budgets ──────────────────────────────────────
      // { 'yyyy-MM': number }
      monthlyBudgets: {},
      setMonthlyBudget: (month, amount) =>
        set((s) => ({ monthlyBudgets: { ...s.monthlyBudgets, [month]: Number(amount) } })),
      distributeEvenly: () => {
        const { project } = get()
        const months = generateMonths(project.startDate, project.endDate)
        if (!months.length) return
        const perMonth = Math.round(project.totalBudget / months.length)
        const budgets = {}
        months.forEach((m) => (budgets[m] = perMonth))
        set({ monthlyBudgets: budgets })
      },

      // ─── Roles ────────────────────────────────────────────────
      roles: [],
      addRole: (role) =>
        set((s) => ({
          roles: [
            ...s.roles,
            {
              id: crypto.randomUUID(),
              name: role.name || 'Neue Rolle',
              hourlyRate: Number(role.hourlyRate) || 0,
              color: role.color || '#6366f1',
              // availability per month: { 'yyyy-MM': { hoursPerWeek, vacationDays } }
              availability: {},
            },
          ],
        })),
      updateRole: (id, data) =>
        set((s) => ({
          roles: s.roles.map((r) => (r.id === id ? { ...r, ...data } : r)),
        })),
      removeRole: (id) =>
        set((s) => ({ roles: s.roles.filter((r) => r.id !== id) })),
      setRoleAvailability: (roleId, month, data) =>
        set((s) => ({
          roles: s.roles.map((r) =>
            r.id === roleId
              ? {
                  ...r,
                  availability: {
                    ...r.availability,
                    [month]: { ...r.availability[month], ...data },
                  },
                }
              : r
          ),
        })),

      // ─── Actual Hours (Controlling) ───────────────────────────
      // { roleId: { 'yyyy-MM': actualHours } }
      actualHours: {},
      setActualHours: (roleId, month, hours) =>
        set((s) => ({
          actualHours: {
            ...s.actualHours,
            [roleId]: {
              ...(s.actualHours[roleId] || {}),
              [month]: Number(hours),
            },
          },
        })),

      // ─── Derived helpers ──────────────────────────────────────
      getMonths: () => {
        const { project } = get()
        return generateMonths(project.startDate, project.endDate)
      },

      getMonthlyCapacity: (roleId, month) => {
        const { roles } = get()
        const role = roles.find((r) => r.id === roleId)
        if (!role) return 0
        const avail = role.availability[month]
        const hoursPerWeek = avail?.hoursPerWeek ?? 40
        const vacationDays = avail?.vacationDays ?? 0
        const date = new Date(month + '-01')
        const daysInMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate()
        const workDays = Math.round((daysInMonth / 7) * 5) - vacationDays
        return Math.max(0, (hoursPerWeek / 5) * workDays)
      },

      getTotalPlannedCost: (month) => {
        const { roles, getMonthlyCapacity } = get()
        return roles.reduce((sum, r) => {
          const cap = getMonthlyCapacity(r.id, month)
          return sum + cap * r.hourlyRate
        }, 0)
      },

      getTotalActualCost: (month) => {
        const { roles, actualHours } = get()
        return roles.reduce((sum, r) => {
          const hrs = actualHours[r.id]?.[month] ?? 0
          return sum + hrs * r.hourlyRate
        }, 0)
      },
    }),
    { name: 'budget-tracker-v1' }
  )
)
