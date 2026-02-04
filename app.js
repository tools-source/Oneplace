// DOM Elements
const descriptionInput = document.getElementById('description');
const amountInput = document.getElementById('amount');
const categorySelect = document.getElementById('category');
const urgencySelect = document.getElementById('urgency');
const categoryFilter = document.getElementById('category-filter');
const urgencyFilter = document.getElementById('urgency-filter');
const transactionSearchInput = document.getElementById('transaction-search');
const addTransactionButton = document.getElementById('add-transaction');
const saveTransactionButton = document.getElementById('save-transaction');
const balanceElement = document.getElementById('balance');
const balanceScope = document.getElementById('balance-scope');
const historyList = document.getElementById('history-list');
const historySection = document.getElementById('history-section');
const toggleHistoryButton = document.getElementById('toggle-history');
const inputSection = document.getElementById('input-section');
const toggleInputButton = document.getElementById('toggle-input');
const exportDataButton = document.getElementById('export-data');
const exportBackupButton = document.getElementById('export-backup');
const importTransactionsButton = document.getElementById('import-transactions');
const importDataInput = document.getElementById('import-data');
const clearDataButton = document.getElementById('clear-data');
const loadDemoDataButton = document.getElementById('load-demo-data');
const openHelpButton = document.getElementById('open-help');
const tabButtons = document.querySelectorAll('[data-tab-target]');
const tabPanels = document.querySelectorAll('[data-tab-panel]');
const tabNav = document.querySelector('.tab-nav');
const categoryPillGroup = document.getElementById('category-pill-group');
const categoryHint = document.getElementById('category-hint');
const categoryGuidance = document.getElementById('category-guidance');
const customCategoryNameInput = document.getElementById('custom-category-name');
const customCategoryTypeSelect = document.getElementById('custom-category-type');
const addCategoryButton = document.getElementById('add-category');
const themeToggle = document.getElementById('theme-toggle');
const themeModeButtons = document.querySelectorAll('[data-theme-mode]');
const accentOptionsContainer = document.getElementById('accent-options');
const insightIncome = document.getElementById('insight-income');
const insightExpense = document.getElementById('insight-expense');
const insightTopCategory = document.getElementById('insight-top-category');
const insightTopCategoryAmount = document.getElementById('insight-top-category-amount');
const insightRecent = document.getElementById('insight-recent');
const spendingTrend = document.getElementById('spending-trend');
const categoryBalanceIndicator = document.getElementById('category-balance-indicator');
const todoForm = document.getElementById('todo-form');
const todoInput = document.getElementById('todo-input');
const todoDueDateInput = document.getElementById('todo-due-date');
const todoPriority = document.getElementById('todo-priority');
const todoList = document.getElementById('todo-list');
const todoProgress = document.getElementById('todo-progress');
const todoSearchInput = document.getElementById('todo-search');
const sharedParticipantList = document.getElementById('shared-participant-list');
const sharedParticipantForm = document.getElementById('shared-participant-form');
const sharedParticipantInput = document.getElementById('shared-participant-input');
const sharedExpenseForm = document.getElementById('shared-expense-form');
const sharedExpenseDescription = document.getElementById('shared-expense-description');
const sharedExpenseAmount = document.getElementById('shared-expense-amount');
const sharedExpensePayer = document.getElementById('shared-expense-payer');
const sharedExpenseParticipants = document.getElementById('shared-expense-participants');
const sharedExpenseHistory = document.getElementById('shared-expense-history');
const sharedExpenseSummary = document.getElementById('shared-expense-summary');
const resetSharedBalancesButton = document.getElementById('reset-shared-balances');
const shareSplitSummaryButton = document.getElementById('share-split-summary');
const communicationForm = document.getElementById('communication-form');
const communicationTitleInput = document.getElementById('communication-title');
const communicationPhraseInput = document.getElementById('communication-phrase');
const communicationImageInput = document.getElementById('communication-image');
const communicationEmojiInput = document.getElementById('communication-emoji');
const communicationLanguageSelect = document.getElementById('communication-language');
const communicationPreview = document.getElementById('communication-preview');
const communicationGrid = document.getElementById('communication-grid');
const communicationRecordButton = document.getElementById('communication-record');
const communicationPlayRecordingButton = document.getElementById('communication-play-recording');
const communicationStopButton = document.getElementById('communication-stop');
const communicationRecordingStatus = document.getElementById('communication-recording-status');
const communicationSubmitButton = document.getElementById('communication-submit');
const communicationCancelButton = document.getElementById('communication-cancel');
const communicationFormToggle = document.getElementById('communication-form-toggle');
const communicationFormBody = document.getElementById('communication-form-body');
const shortcutForm = document.getElementById('shortcut-form');
const shortcutTitleInput = document.getElementById('shortcut-title');
const shortcutDescriptionInput = document.getElementById('shortcut-description');
const shortcutRoutineInput = document.getElementById('shortcut-routine');
const shortcutLinkInput = document.getElementById('shortcut-link');
const shortcutList = document.getElementById('shortcut-list');
const shortcutCount = document.getElementById('shortcut-count');
const reminderForm = document.getElementById('reminder-form');
const reminderTitleInput = document.getElementById('reminder-title');
const reminderMessageInput = document.getElementById('reminder-message');
const reminderTimeInput = document.getElementById('reminder-time');
const reminderRecurrenceSelect = document.getElementById('reminder-recurrence');
const reminderWeekdayInputs = document.querySelectorAll('[data-reminder-weekday]');
const reminderWeekdayGroup = document.getElementById('reminder-weekday-group');
const reminderMonthlyGroup = document.getElementById('reminder-monthly-group');
const reminderMonthlyDaySelect = document.getElementById('reminder-monthly-day');
const reminderList = document.getElementById('reminder-list');
const reminderCount = document.getElementById('reminder-count');
const notificationStatus = document.getElementById('notification-status');
const pushStatus = document.getElementById('push-status');
const requestNotificationPermissionButton = document.getElementById('request-notification-permission');
const copyPushSubscriptionButton = document.getElementById('copy-push-subscription');
const clearPushSubscriptionButton = document.getElementById('clear-push-subscription');
const THEME_STORAGE_KEY = 'themeMode';
const ACCENT_STORAGE_KEY = 'accentColor';
const CUSTOM_CATEGORIES_KEY = 'customCategories';
const TODO_STORAGE_KEY = 'organizerTodos';
const SHARED_PARTICIPANTS_KEY = 'sharedParticipants';
const SHARED_EXPENSES_KEY = 'sharedExpenses';
const COMMUNICATION_ITEMS_KEY = 'communicationItems';
const SHORTCUTS_STORAGE_KEY = 'iphoneShortcuts';
const REMINDER_STORAGE_KEY = 'phoneReminders';
const ACTIVE_TAB_STORAGE_KEY = 'activeTab';
const COMMUNICATION_FORM_COLLAPSE_KEY = 'communicationFormCollapsed';
const PUSH_SUBSCRIPTION_KEY = 'pushSubscription';
const VAPID_PUBLIC_KEY = '';

const safeStorage = {
    get(key) {
        try {
            return localStorage.getItem(key);
        } catch (error) {
            return null;
        }
    },
    set(key, value) {
        try {
            localStorage.setItem(key, value);
        } catch (error) {
            // Ignore storage errors (e.g. disabled storage or quota exceeded).
        }
    },
    remove(key) {
        try {
            localStorage.removeItem(key);
        } catch (error) {
            // Ignore storage errors (e.g. disabled storage or quota exceeded).
        }
    }
};

const safeJsonParse = (key, fallback) => {
    const rawValue = safeStorage.get(key);
    if (!rawValue) return fallback;
    try {
        return JSON.parse(rawValue);
    } catch (error) {
        return fallback;
    }
};

let transactions = safeJsonParse('transactions', []);
let editTransactionId = null;
let customCategories = safeJsonParse(CUSTOM_CATEGORIES_KEY, []);
let todos = safeJsonParse(TODO_STORAGE_KEY, []);
let sharedParticipants = safeJsonParse(SHARED_PARTICIPANTS_KEY, []);
let sharedExpenses = safeJsonParse(SHARED_EXPENSES_KEY, []);
let communicationItems = safeJsonParse(COMMUNICATION_ITEMS_KEY, []);
let shortcuts = safeJsonParse(SHORTCUTS_STORAGE_KEY, []);
let reminders = safeJsonParse(REMINDER_STORAGE_KEY, []);
let editingCommunicationId = null;
let communicationAudioData = '';
let recordingChunks = [];
let mediaRecorder = null;
let recordingStream = null;
let activeAudioElement = null;
let isCommunicationAudioPlaying = false;
let reminderCheckInterval = null;
let reminderSchedulingInProgress = false;
let transactionSearchQuery = '';
let todoSearchQuery = '';
const REMINDER_WEEKDAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const REMINDER_NOTIFICATION_ICON = 'assets/icons/icon-192.png';
const REMINDER_NOTIFICATION_BADGE = 'assets/icons/icon-72.png';
const IS_IOS = /iphone|ipad|ipod/i.test(window.navigator.userAgent || '');
const IS_STANDALONE = window.matchMedia
    ? window.matchMedia('(display-mode: standalone)').matches
    : Boolean(window.navigator.standalone);
const prefersDarkScheme = window.matchMedia
    ? window.matchMedia('(prefers-color-scheme: dark)')
    : { matches: false, addEventListener: () => {}, removeEventListener: () => {}, addListener: () => {}, removeListener: () => {} };

const BASE_CATEGORY_CONFIG = [
    { value: 'salary', label: 'Salary', type: 'income', color: '#28a745', hint: 'Log your paycheck or recurring income.' },
    { value: 'freelance', label: 'Freelance', type: 'income', color: '#20c997', hint: 'Track side gigs and one-off projects.' },
    { value: 'investments', label: 'Investments', type: 'income', color: '#198754', hint: 'Record dividends, interest, or payouts.' },
    { value: 'other-income', label: 'Other Income', type: 'income', color: '#25ba4e', hint: 'Gifts, reimbursements, and misc gains.' },
    { value: 'food', label: 'Food & Dining', type: 'expense', color: '#dc3545', hint: 'Dining out, groceries, and coffee runs.' },
    { value: 'transport', label: 'Transport', type: 'expense', color: '#fd7e14', hint: 'Fuel, rideshares, public transit, parking.' },
    { value: 'bills', label: 'Bills & Utilities', type: 'expense', color: '#6f42c1', hint: 'Electricity, rent, subscriptions, and more.' },
    { value: 'shopping', label: 'Shopping', type: 'expense', color: '#e83e8c', hint: 'Clothes, gifts, and retail therapy.' },
    { value: 'entertainment', label: 'Entertainment', type: 'expense', color: '#0dcaf0', hint: 'Streaming, movies, concerts, and fun.' },
    { value: 'health', label: 'Healthcare', type: 'expense', color: '#20c997', hint: 'Medical, wellness, and pharmacy costs.' },
    { value: 'education', label: 'Education', type: 'expense', color: '#0d6efd', hint: 'Courses, supplies, and learning tools.' },
    { value: 'other-expense', label: 'Other Expense', type: 'expense', color: '#6c757d', hint: 'Everything that does not fit elsewhere.' }
];

const buildCategoryLookup = (categories) => categories.reduce((acc, category) => {
    acc[category.value] = category;
    return acc;
}, {});

const getAllCategories = () => [
    ...BASE_CATEGORY_CONFIG,
    ...(Array.isArray(customCategories) ? customCategories : [])
];

let CATEGORY_LOOKUP = buildCategoryLookup(getAllCategories());

const URGENCY_OPTIONS = [
    { value: 'urgent', label: 'Urgent', badgeClass: 'bg-danger' },
    { value: 'not-urgent', label: 'Not urgent', badgeClass: 'bg-secondary' },
    { value: 'later', label: 'Later', badgeClass: 'bg-info' }
];

const URGENCY_LOOKUP = URGENCY_OPTIONS.reduce((acc, option) => {
    acc[option.value] = option;
    return acc;
}, {});
const URGENCY_SORT_ORDER = {
    urgent: 0,
    'not-urgent': 1,
    later: 2
};

// Category Management
const getCategoryColor = (categoryValue) => {
    return CATEGORY_LOOKUP[categoryValue]?.color || '#6c757d';
};

const getCategoryName = (categoryValue) => {
    return CATEGORY_LOOKUP[categoryValue]?.label || 'Uncategorized';
};

const getCategoryConfig = (categoryValue) => CATEGORY_LOOKUP[categoryValue];

const DEFAULT_URGENCY = 'not-urgent';
const getUrgencyLabel = (urgencyValue) => URGENCY_LOOKUP[urgencyValue]?.label || 'Not urgent';
const getUrgencyBadgeClass = (urgencyValue) => URGENCY_LOOKUP[urgencyValue]?.badgeClass || 'bg-secondary';

const hexToRgba = (hex, alpha = 1) => {
    if (!hex) return `rgba(0,0,0,${alpha})`;
    const sanitized = hex.replace('#', '');
    const bigint = parseInt(sanitized, 16);
    const r = (bigint >> 16) & 255;
    const g = (bigint >> 8) & 255;
    const b = bigint & 255;
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
};

const DEFAULT_CATEGORY_HINT = 'Choose a category to see smart tips.';
const DEFAULT_GUIDANCE = 'Picking a category will auto-select the right type.';
let activeCategoryFilter = categoryFilter?.value || '';
let activeUrgencyFilter = urgencyFilter?.value || '';
const TODO_PRIORITY_META = {
    high: { label: 'High', className: 'bg-danger', icon: 'bi-exclamation-triangle-fill' },
    normal: { label: 'Normal', className: 'bg-secondary', icon: 'bi-circle-fill' },
    low: { label: 'Low', className: 'bg-success', icon: 'bi-arrow-down-circle-fill' }
};
const TODO_PRIORITY_ORDER = { high: 3, normal: 2, low: 1 };
const MAX_ORDER_VALUE = 100;
const DEFAULT_COMMUNICATION_ITEMS = [
    {
        id: 'comm-drink',
        title: 'I want a drink',
        phrase: 'I would like a drink, please.',
        emoji: '🧃',
        lang: 'en',
        color: '#0d6efd',
        isCustom: false,
        audioData: ''
    },
    {
        id: 'comm-snack',
        title: 'I am hungry',
        phrase: 'I am hungry. Can I have something to eat?',
        emoji: '🍎',
        lang: 'en',
        color: '#fd7e14',
        isCustom: false,
        audioData: ''
    },
    {
        id: 'comm-bathroom',
        title: 'Bathroom',
        phrase: 'I need to use the bathroom.',
        emoji: '🚻',
        lang: 'en',
        color: '#20c997',
        isCustom: false,
        audioData: ''
    },
    {
        id: 'comm-help',
        title: 'Help me',
        phrase: 'Please help me.',
        emoji: '🆘',
        lang: 'en',
        color: '#dc3545',
        isCustom: false,
        audioData: ''
    },
    {
        id: 'comm-break',
        title: 'I need a break',
        phrase: 'I need a break.',
        emoji: '🧸',
        lang: 'en',
        color: '#6f42c1',
        isCustom: false,
        audioData: ''
    },
    {
        id: 'comm-spanish-greeting',
        title: 'Hola',
        phrase: 'Hola, ¿puedo tener esto?',
        emoji: '😊',
        lang: 'es',
        color: '#17a2b8',
        isCustom: false,
        audioData: ''
    },
    {
        id: 'comm-ar-hello',
        title: 'مرحبا',
        phrase: 'مرحباً، كيف حالك اليوم؟',
        emoji: '👋',
        lang: 'ar',
        color: '#0d6efd',
        isCustom: false,
        audioData: ''
    },
    {
        id: 'comm-ar-thanks',
        title: 'شكراً',
        phrase: 'شكراً جزيلاً على مساعدتك.',
        emoji: '🙏',
        lang: 'ar',
        color: '#20c997',
        isCustom: false,
        audioData: ''
    }
];
const DEFAULT_SHORTCUTS = [
    {
        id: 'shortcut-morning-briefing',
        title: 'Morning Briefing',
        description: 'Opens weather, calendar, and today’s top tasks.',
        routine: 'Right after I wake up',
        link: ''
    },
    {
        id: 'shortcut-commute-eta',
        title: 'Commute ETA',
        description: 'Sends my ETA to a favorite contact.',
        routine: 'When I leave home',
        link: ''
    },
    {
        id: 'shortcut-focus-sprint',
        title: 'Focus Sprint',
        description: 'Starts a focus playlist and a 25-minute timer.',
        routine: 'Before deep work',
        link: ''
    },
    {
        id: 'shortcut-hydration',
        title: 'Hydration Log',
        description: 'Logs water intake and updates a hydration reminder.',
        routine: 'After I refill my bottle',
        link: ''
    }
];

const currencyFormatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
});

const formatCurrency = (value, { includePlus = false } = {}) => {
    const base = currencyFormatter.format(Math.abs(value));
    if (value < 0) return `-${base}`;
    if (value > 0 && includePlus) return `+${base}`;
    return base;
};

const escapeCsvCell = (value) => `"${String(value ?? '').replace(/"/g, '""')}"`;

const stripLeadingEmoji = (text = '', emoji = '') => {
    if (!text) return '';
    const trimmedText = text.trimStart();
    if (!emoji) return trimmedText;
    const normalizedEmoji = emoji.trim();
    return normalizedEmoji && trimmedText.startsWith(normalizedEmoji)
        ? trimmedText.slice(normalizedEmoji.length).trimStart()
        : trimmedText;
};

const normalizeEmojiValue = (value = '', fallback = '🗣️') => {
    const normalized = Array.from((value || '').trim()).slice(0, 2).join('');
    return normalized || fallback;
};

const calculateNet = (list = []) => list.reduce((sum, transaction) => {
    const amount = Math.abs(transaction.amount);
    return transaction.type === 'income' ? sum + amount : sum - amount;
}, 0);

const escapeHtml = (value = '') => value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\"/g, '&quot;')
    .replace(/'/g, '&#039;');

const formatTodoDueDate = (dateValue) => {
    if (!dateValue) return '';
    const date = new Date(`${dateValue}T00:00:00`);
    if (Number.isNaN(date.getTime())) return dateValue;
    const now = new Date();
    const options = {
        month: 'short',
        day: 'numeric',
        ...(date.getFullYear() !== now.getFullYear() ? { year: 'numeric' } : {})
    };
    return date.toLocaleDateString(undefined, options);
};

const getFilteredTransactions = () => {
    return transactions.filter(transaction => {
        const matchesCategory = !activeCategoryFilter || transaction.category === activeCategoryFilter;
        const matchesUrgency = !activeUrgencyFilter || transaction.urgency === activeUrgencyFilter;
        const description = (transaction.description || '').toLowerCase();
        const matchesSearch = !transactionSearchQuery
            || description.includes(transactionSearchQuery)
            || getCategoryName(transaction.category).toLowerCase().includes(transactionSearchQuery);
        return matchesCategory && matchesUrgency && matchesSearch;
    });
};

const generateId = () => Date.now() + Math.floor(Math.random() * 1000);

const normalizeUrgencyValue = (value) => (
    URGENCY_LOOKUP[value] ? value : DEFAULT_URGENCY
);

const getUrgencySortValue = (urgency) => (
    URGENCY_SORT_ORDER[normalizeUrgencyValue(urgency)] ?? URGENCY_SORT_ORDER[DEFAULT_URGENCY]
);

const normalizeTransaction = (transaction, index = 0) => {
    const rawAmount = Number(transaction.amount);
    const normalizedAmount = Number.isFinite(rawAmount) ? Math.abs(rawAmount) : 0;
    const type = transaction.type === 'income' || transaction.type === 'expense'
        ? transaction.type
        : rawAmount < 0
            ? 'expense'
            : 'income';

    return {
        id: typeof transaction.id === 'number' ? transaction.id : generateId() + index,
        description: transaction.description || '',
        amount: normalizedAmount,
        type,
        category: typeof transaction.category === 'string' ? transaction.category : '',
        urgency: normalizeUrgencyValue(transaction.urgency),
        date: transaction.date || transaction.dateModified || new Date().toISOString()
    };
};

const loadTransactions = () => {
    const stored = safeJsonParse('transactions', []);
    return Array.isArray(stored) ? stored.map(normalizeTransaction) : [];
};

const createDefaultSharedParticipants = () => {
    const baseId = Date.now();
    return [{ id: baseId, name: 'You' }];
};

const filterTransactions = () => {
    activeCategoryFilter = categoryFilter.value;
    activeUrgencyFilter = urgencyFilter?.value || '';
    displayTransactions();
    updateBalance();
};

const getFilterLabel = () => {
    const parts = [];
    if (activeCategoryFilter) {
        parts.push(getCategoryName(activeCategoryFilter));
    } else if (activeUrgencyFilter) {
        parts.push('All categories');
    }
    if (activeUrgencyFilter) parts.push(getUrgencyLabel(activeUrgencyFilter));
    return parts.length ? parts.join(' · ') : 'All categories';
};

const normalizeCustomCategories = (categories = []) => (
    Array.isArray(categories)
        ? categories.map((category, index) => ({
            value: category.value || `custom-${generateId() + index}`,
            label: category.label || 'Custom',
            type: category.type === 'income' ? 'income' : 'expense',
            color: category.color || '#0d6efd'
        }))
        : []
);

const normalizeTodo = (todo, index = 0) => ({
    ...todo,
    order: typeof todo.order === 'number' ? todo.order : Math.min((index + 1) * 10, MAX_ORDER_VALUE),
    subtasks: Array.isArray(todo.subtasks) ? todo.subtasks : [],
    dueDate: todo.dueDate || ''
});

const sortTodos = (list) => list
    .slice()
    .sort((a, b) => {
        const priorityDiff = (TODO_PRIORITY_ORDER[b.priority] || 0) - (TODO_PRIORITY_ORDER[a.priority] || 0);
        if (priorityDiff !== 0) return priorityDiff;
        const hasDueDateA = Boolean(a.dueDate);
        const hasDueDateB = Boolean(b.dueDate);
        if (hasDueDateA && hasDueDateB) {
            const dueDiff = new Date(`${a.dueDate}T00:00:00`) - new Date(`${b.dueDate}T00:00:00`);
            if (dueDiff !== 0) return dueDiff;
        } else if (hasDueDateA) {
            return -1;
        } else if (hasDueDateB) {
            return 1;
        }
        const orderDiff = (a.order ?? 50) - (b.order ?? 50);
        if (orderDiff !== 0) return orderDiff;
        return new Date(a.createdAt) - new Date(b.createdAt);
    });

transactions = loadTransactions();
customCategories = normalizeCustomCategories(customCategories);
CATEGORY_LOOKUP = buildCategoryLookup(getAllCategories());
todos = Array.isArray(todos) ? todos.map((todo, index) => normalizeTodo(todo, index)) : [];
sharedParticipants = Array.isArray(sharedParticipants)
    ? sharedParticipants.map((participant, index) => ({
        id: typeof participant.id === 'number' ? participant.id : generateId() + index,
        name: participant.name || `Member ${index + 1}`
    }))
    : [];
sharedExpenses = Array.isArray(sharedExpenses)
    ? sharedExpenses.map(expense => ({
        ...expense,
        id: typeof expense.id === 'number' ? expense.id : generateId(),
        amount: Number(expense.amount) || 0,
        participantIds: Array.isArray(expense.participantIds) ? expense.participantIds : [],
        date: expense.date || new Date().toISOString()
    }))
    : [];
communicationItems = Array.isArray(communicationItems)
    ? communicationItems.map((item, index) => ({
        id: item.id || `comm-${generateId() + index}`,
        title: item.title || 'New card',
        phrase: item.phrase || '',
        lang: item.lang || 'en',
        audioData: item.audioData || '',
        emoji: item.emoji || '💬',
        color: item.color || '#0d6efd',
        imageData: item.imageData || '',
        isCustom: item.isCustom ?? true
    }))
    : [];
shortcuts = Array.isArray(shortcuts)
    ? shortcuts.map((shortcut, index) => ({
        id: shortcut.id || `shortcut-${generateId() + index}`,
        title: shortcut.title || 'New shortcut',
        description: shortcut.description || '',
        routine: shortcut.routine || '',
        link: shortcut.link || '',
        createdAt: shortcut.createdAt || new Date().toISOString()
    }))
    : [];
reminders = Array.isArray(reminders)
    ? reminders.map((reminder, index) => ({
        id: typeof reminder.id === 'number' ? reminder.id : generateId() + index,
        title: reminder.title || 'Reminder',
        message: reminder.message || '',
        time: reminder.time || new Date().toISOString(),
        status: reminder.status || 'scheduled',
        createdAt: reminder.createdAt || new Date().toISOString(),
        recurrence: normalizeReminderRecurrence(reminder),
        triggerScheduled: Boolean(reminder.triggerScheduled)
    }))
    : [];
if (!communicationItems.length) {
    communicationItems = DEFAULT_COMMUNICATION_ITEMS.map(item => ({ ...item }));
    safeStorage.set(COMMUNICATION_ITEMS_KEY, JSON.stringify(communicationItems));
}
if (!shortcuts.length) {
    shortcuts = DEFAULT_SHORTCUTS.map(item => ({ ...item }));
    safeStorage.set(SHORTCUTS_STORAGE_KEY, JSON.stringify(shortcuts));
}
if (!sharedParticipants.length) {
    sharedParticipants = createDefaultSharedParticipants();
    safeStorage.set(SHARED_PARTICIPANTS_KEY, JSON.stringify(sharedParticipants));
}

const setActiveTab = (target) => {
    tabButtons.forEach(button => {
        const isActive = button.dataset.tabTarget === target;
        button.classList.toggle('active', isActive);
        button.setAttribute('aria-selected', isActive ? 'true' : 'false');
        button.tabIndex = isActive ? 0 : -1;
    });
    tabPanels.forEach(panel => {
        const isActive = panel.dataset.tabPanel === target;
        panel.classList.toggle('active', isActive);
        panel.setAttribute('aria-hidden', isActive ? 'false' : 'true');
    });
    if (target) {
        safeStorage.set(ACTIVE_TAB_STORAGE_KEY, target);
    }
};

const setupTabs = () => {
    if (tabNav) {
        tabNav.addEventListener('click', (event) => {
            const button = event.target.closest('[data-tab-target]');
            if (!button) return;
            setActiveTab(button.dataset.tabTarget);
        });
        return;
    }
    tabButtons.forEach(button => {
        button.addEventListener('click', () => setActiveTab(button.dataset.tabTarget));
    });
};

const updateCommunicationFormToggle = (isExpanded) => {
    if (!communicationFormToggle) return;
    communicationFormToggle.innerHTML = `
        <i class="bi bi-chevron-${isExpanded ? 'up' : 'down'}"></i>
        <span class="visually-hidden">Toggle create button form</span>
    `;
    communicationFormToggle.setAttribute('aria-expanded', isExpanded ? 'true' : 'false');
};

const applyCommunicationFormState = (shouldExpand) => {
    if (!communicationFormBody) return;
    communicationFormBody.classList.toggle('show', shouldExpand);
    updateCommunicationFormToggle(shouldExpand);
    safeStorage.set(COMMUNICATION_FORM_COLLAPSE_KEY, shouldExpand ? 'expanded' : 'collapsed');
};

const saveTodos = () => {
    safeStorage.set(TODO_STORAGE_KEY, JSON.stringify(todos));
};

const saveSharedParticipants = () => {
    safeStorage.set(SHARED_PARTICIPANTS_KEY, JSON.stringify(sharedParticipants));
};

const saveSharedExpenses = () => {
    safeStorage.set(SHARED_EXPENSES_KEY, JSON.stringify(sharedExpenses));
};

const saveReminders = () => {
    safeStorage.set(REMINDER_STORAGE_KEY, JSON.stringify(reminders));
};

const formatLocalDateTime = (date) => {
    const offset = date.getTimezoneOffset();
    const localTime = new Date(date.getTime() - offset * 60000);
    return localTime.toISOString().slice(0, 16);
};

const formatReminderTime = (time) => {
    const date = new Date(time);
    if (Number.isNaN(date.getTime())) return 'Invalid date';
    return date.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
};

const getReminderRecurrenceSummary = (recurrence) => {
    if (!recurrence || recurrence.frequency === 'none') return '';
    if (recurrence.frequency === 'monthly') {
        const day = recurrence.dayOfMonth || 1;
        return `Repeats monthly on day ${day}`;
    }
    const days = Array.isArray(recurrence.daysOfWeek)
        ? recurrence.daysOfWeek.map((day) => REMINDER_WEEKDAY_LABELS[day]).filter(Boolean)
        : [];
    const dayLabel = days.length ? ` on ${days.join(', ')}` : '';
    return recurrence.frequency === 'biweekly'
        ? `Repeats every 2 weeks${dayLabel}`
        : `Repeats weekly${dayLabel}`;
};

const getReminderStatusMeta = (status) => {
    switch (status) {
        case 'sent':
            return { label: 'Sent', className: 'bg-success-subtle text-success-emphasis' };
        case 'missed':
            return { label: 'Missed', className: 'bg-secondary-subtle text-secondary-emphasis' };
        default:
            return { label: 'Scheduled', className: 'bg-primary-subtle text-primary-emphasis' };
    }
};

const updateReminderCount = () => {
    if (!reminderCount) return;
    const scheduledCount = reminders.filter(reminder => reminder.status === 'scheduled').length;
    reminderCount.textContent = `${scheduledCount} scheduled`;
};

const supportsNotificationTriggers = () => 'serviceWorker' in navigator && 'TimestampTrigger' in window;
const supportsPushNotifications = () => 'serviceWorker' in navigator && 'PushManager' in window;

const urlBase64ToUint8Array = (base64String) => {
    const padded = `${base64String}${'='.repeat((4 - (base64String.length % 4)) % 4)}`;
    const base64 = padded.replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; i += 1) {
        outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
};

const renderReminders = () => {
    if (!reminderList) return;
    reminderList.innerHTML = '';

    if (!reminders.length) {
        reminderList.innerHTML = '<li class="list-group-item text-center text-muted py-4">No reminders yet</li>';
        updateReminderCount();
        return;
    }

    const sortedReminders = [...reminders].sort((a, b) => new Date(a.time) - new Date(b.time));
    sortedReminders.forEach(reminder => {
        const listItem = document.createElement('li');
        listItem.className = 'list-group-item reminder-item';
        listItem.dataset.id = reminder.id;
        const statusMeta = getReminderStatusMeta(reminder.status);
        const safeTitle = escapeHtml(reminder.title || '');
        const safeMessage = escapeHtml(reminder.message || '');
        const messageMarkup = safeMessage
            ? `<p class="mb-2 reminder-meta text-muted">${safeMessage}</p>`
            : '<p class="mb-2 reminder-meta text-muted">No additional message</p>';
        const recurrenceSummary = getReminderRecurrenceSummary(reminder.recurrence);
        const recurrenceMarkup = recurrenceSummary
            ? `<p class="mb-2 reminder-meta text-muted"><i class="bi bi-repeat me-1"></i>${recurrenceSummary}</p>`
            : '';
        const calendarHref = buildReminderCalendarHref(reminder);

        listItem.innerHTML = `
            <div class="d-flex justify-content-between align-items-start gap-3">
                <div>
                    <div class="d-flex align-items-center gap-2 flex-wrap mb-2">
                        <h5 class="mb-0">${safeTitle}</h5>
                        <span class="badge ${statusMeta.className}">${statusMeta.label}</span>
                    </div>
                    ${messageMarkup}
                    ${recurrenceMarkup}
                    <p class="mb-0 reminder-meta"><i class="bi bi-clock me-1"></i>${formatReminderTime(reminder.time)}</p>
                </div>
                <div class="d-flex flex-column gap-2">
                    <a class="btn btn-sm btn-outline-secondary" href="${calendarHref}" download="reminder-${reminder.id}.ics" data-action="add-to-calendar" aria-label="Add reminder to calendar">
                        <i class="bi bi-calendar-event me-1"></i>Add to calendar
                    </a>
                    <button class="btn btn-sm btn-outline-danger" data-action="delete-reminder" aria-label="Delete reminder">
                        <i class="bi bi-x-lg"></i>
                    </button>
                </div>
            </div>
        `;
        reminderList.appendChild(listItem);
    });
    updateReminderCount();
};

const getNotificationStatusDetails = () => {
    if (!('Notification' in window)) {
        return {
            text: 'Notifications are not supported in this browser.',
            canRequest: false
        };
    }
    const supportsBackground = supportsNotificationTriggers();
    if (IS_IOS && !IS_STANDALONE) {
        return {
            text: 'Install this site to your Home Screen to enable iPhone notifications.',
            canRequest: false
        };
    }
    if (Notification.permission === 'granted') {
        if (IS_IOS && !supportsBackground) {
            return {
                text: 'Enabled, but iOS cannot schedule lock-screen alerts yet. Use “Add to calendar” for locked-screen reminders.',
                canRequest: false
            };
        }
        if (supportsBackground) {
            const suffix = IS_STANDALONE
                ? 'Background scheduling is active, including on locked screens.'
                : 'Install the app to enable background scheduling on locked screens.';
            return { text: `Enabled. ${suffix}`, canRequest: false };
        }
        return {
            text: 'Enabled, but this browser can only alert while the app stays open. Use “Add to calendar” for locked-screen alerts.',
            canRequest: false
        };
    }
    if (Notification.permission === 'denied') {
        return { text: 'Blocked. Enable notifications in browser settings.', canRequest: true };
    }
    return { text: 'Not enabled yet. Tap enable to allow alerts.', canRequest: true };
};

const updateNotificationStatus = () => {
    if (!notificationStatus) return;
    const details = getNotificationStatusDetails();
    notificationStatus.textContent = details.text;
    if (requestNotificationPermissionButton) {
        requestNotificationPermissionButton.disabled = !details.canRequest;
    }
};

const getPushStatusDetails = async () => {
    if (!pushStatus) return { text: '', canCopy: false, canClear: false };
    if (!supportsPushNotifications()) {
        return { text: 'Push messaging is not supported in this browser.', canCopy: false, canClear: false };
    }
    if (!VAPID_PUBLIC_KEY) {
        return { text: 'Add a VAPID public key in app.js to enable push.', canCopy: false, canClear: false };
    }
    if (Notification.permission !== 'granted') {
        return { text: 'Enable notifications to register for push.', canCopy: false, canClear: false };
    }
    try {
        const registration = await navigator.serviceWorker.ready;
        const subscription = await registration.pushManager.getSubscription();
        if (!subscription) {
            return { text: 'Push not subscribed yet.', canCopy: false, canClear: false };
        }
        return { text: 'Push subscription active. Use copy to share with your server.', canCopy: true, canClear: true };
    } catch (error) {
        console.warn('Unable to read push subscription.', error);
        return { text: 'Push subscription unavailable.', canCopy: false, canClear: false };
    }
};

const updatePushStatus = async () => {
    if (!pushStatus) return;
    const details = await getPushStatusDetails();
    pushStatus.textContent = details.text;
    if (copyPushSubscriptionButton) {
        copyPushSubscriptionButton.disabled = !details.canCopy;
    }
    if (clearPushSubscriptionButton) {
        clearPushSubscriptionButton.disabled = !details.canClear;
    }
};

const requestNotificationPermission = () => {
    if (!('Notification' in window)) return;
    Notification.requestPermission().then(() => {
        updateNotificationStatus();
        updatePushStatus();
        schedulePendingReminderTriggers();
        subscribeToPushNotifications();
    });
};

const updateReminderTimeMin = () => {
    if (!reminderTimeInput) return;
    const minTime = new Date();
    minTime.setMinutes(minTime.getMinutes() + 1);
    reminderTimeInput.min = formatLocalDateTime(minTime);
};

const buildMonthlyDayOptions = () => {
    if (!reminderMonthlyDaySelect) return;
    reminderMonthlyDaySelect.innerHTML = '';
    for (let day = 1; day <= 31; day += 1) {
        const option = document.createElement('option');
        option.value = String(day);
        option.textContent = String(day);
        reminderMonthlyDaySelect.appendChild(option);
    }
};

const setMonthlyDayFromTime = () => {
    if (!reminderMonthlyDaySelect || !reminderTimeInput?.value) return;
    const selectedDate = new Date(reminderTimeInput.value);
    if (Number.isNaN(selectedDate.getTime())) return;
    reminderMonthlyDaySelect.value = String(selectedDate.getDate());
};

const getSelectedWeekdays = () => {
    if (!reminderWeekdayInputs?.length) return [];
    return Array.from(reminderWeekdayInputs)
        .filter((input) => input.checked)
        .map((input) => parseInt(input.dataset.reminderWeekday, 10))
        .filter((value) => Number.isInteger(value) && value >= 0 && value <= 6);
};

const formatIcsDate = (date) => {
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) return '';
    const pad = (value) => String(value).padStart(2, '0');
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}T${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}Z`;
};

const buildReminderRrule = (reminder) => {
    const recurrence = normalizeReminderRecurrence(reminder);
    if (!recurrence || recurrence.frequency === 'none') return '';
    if (recurrence.frequency === 'monthly') {
        return `RRULE:FREQ=MONTHLY;BYMONTHDAY=${recurrence.dayOfMonth || 1}`;
    }
    const interval = recurrence.frequency === 'biweekly' ? 2 : 1;
    const days = (recurrence.daysOfWeek?.length ? recurrence.daysOfWeek : [new Date(reminder.time).getDay()])
        .map((day) => ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'][day])
        .filter(Boolean)
        .join(',');
    return `RRULE:FREQ=WEEKLY;INTERVAL=${interval};BYDAY=${days}`;
};

const buildReminderCalendarHref = (reminder) => {
    const start = new Date(reminder.time);
    const end = new Date(start.getTime() + 30 * 60 * 1000);
    const uid = `reminder-${reminder.id}@oneplace`;
    const now = new Date();
    const lines = [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Oneplace//Reminders//EN',
        'CALSCALE:GREGORIAN',
        'BEGIN:VEVENT',
        `UID:${uid}`,
        `DTSTAMP:${formatIcsDate(now)}`,
        `DTSTART:${formatIcsDate(start)}`,
        `DTEND:${formatIcsDate(end)}`,
        `SUMMARY:${(reminder.title || 'Reminder').replace(/\\n/g, ' ')}`,
        `DESCRIPTION:${(reminder.message || '').replace(/\\n/g, ' ')}`
    ];
    const rrule = buildReminderRrule(reminder);
    if (rrule) {
        lines.push(rrule);
    }
    lines.push(
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'DESCRIPTION:Reminder',
        'TRIGGER:-PT0M',
        'END:VALARM',
        'END:VEVENT',
        'END:VCALENDAR'
    );
    return `data:text/calendar;charset=utf-8,${encodeURIComponent(lines.join('\\r\\n'))}`;
};

const setWeekdaySelectionFromTime = () => {
    if (!reminderTimeInput?.value || !reminderWeekdayInputs?.length) return;
    const selectedDate = new Date(reminderTimeInput.value);
    if (Number.isNaN(selectedDate.getTime())) return;
    const selectedDay = selectedDate.getDay();
    const hasChecked = getSelectedWeekdays().length > 0;
    if (hasChecked) return;
    Array.from(reminderWeekdayInputs).forEach((input) => {
        input.checked = parseInt(input.dataset.reminderWeekday, 10) === selectedDay;
    });
};

const updateRecurrenceFields = () => {
    const recurrenceValue = reminderRecurrenceSelect?.value || 'none';
    const showWeekday = recurrenceValue === 'weekly' || recurrenceValue === 'biweekly';
    const showMonthly = recurrenceValue === 'monthly';
    reminderWeekdayGroup?.classList.toggle('d-none', !showWeekday);
    reminderMonthlyGroup?.classList.toggle('d-none', !showMonthly);
    if (showWeekday) {
        setWeekdaySelectionFromTime();
    }
    if (showMonthly) {
        setMonthlyDayFromTime();
    }
};

const buildReminderNotificationOptions = (reminder) => {
    const body = reminder.message?.trim() || 'Reminder time';
    return {
        body,
        tag: `reminder-${reminder.id}`,
        renotify: true,
        icon: REMINDER_NOTIFICATION_ICON,
        badge: REMINDER_NOTIFICATION_BADGE,
        data: {
            reminderId: reminder.id
        },
        requireInteraction: true
    };
};

const sendReminderNotification = async (reminder) => {
    if (!('Notification' in window)) return false;
    if (Notification.permission !== 'granted') return false;
    const title = reminder.title || 'Reminder';
    const options = buildReminderNotificationOptions(reminder);
    if ('serviceWorker' in navigator) {
        try {
            const registration = await navigator.serviceWorker.ready;
            await registration.showNotification(title, options);
            return true;
        } catch (error) {
            console.warn('Unable to display service worker notification.', error);
        }
    }
    try {
        new Notification(title, options);
        return true;
    } catch (error) {
        console.warn('Unable to display notification.', error);
        return false;
    }
};

const registerServiceWorker = async () => {
    if (!('serviceWorker' in navigator)) return null;
    try {
        return await navigator.serviceWorker.register('sw.js');
    } catch (error) {
        console.warn('Service worker registration failed.', error);
        return null;
    }
};

const subscribeToPushNotifications = async () => {
    if (!supportsPushNotifications()) return null;
    if (!VAPID_PUBLIC_KEY) return null;
    if (Notification.permission !== 'granted') return null;
    try {
        const registration = await navigator.serviceWorker.ready;
        const subscription = await registration.pushManager.getSubscription();
        if (subscription) return subscription;
        const newSubscription = await registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY)
        });
        safeStorage.set(PUSH_SUBSCRIPTION_KEY, JSON.stringify(newSubscription.toJSON()));
        return newSubscription;
    } catch (error) {
        console.warn('Unable to subscribe to push notifications.', error);
        return null;
    } finally {
        updatePushStatus();
    }
};

const copyPushSubscription = async () => {
    if (!supportsPushNotifications()) return;
    try {
        const registration = await navigator.serviceWorker.ready;
        const subscription = await registration.pushManager.getSubscription();
        if (!subscription) return;
        const payload = JSON.stringify(subscription.toJSON(), null, 2);
        await navigator.clipboard.writeText(payload);
        pushStatus.textContent = 'Push subscription copied to clipboard.';
    } catch (error) {
        console.warn('Unable to copy push subscription.', error);
    }
};

const clearPushSubscription = async () => {
    if (!supportsPushNotifications()) return;
    try {
        const registration = await navigator.serviceWorker.ready;
        const subscription = await registration.pushManager.getSubscription();
        if (!subscription) return;
        await subscription.unsubscribe();
        safeStorage.remove(PUSH_SUBSCRIPTION_KEY);
        pushStatus.textContent = 'Push subscription cleared.';
    } catch (error) {
        console.warn('Unable to clear push subscription.', error);
    } finally {
        updatePushStatus();
    }
};

const clearScheduledNotification = async (reminderId) => {
    if (!('serviceWorker' in navigator)) return;
    try {
        const registration = await navigator.serviceWorker.ready;
        const notifications = await registration.getNotifications({
            tag: `reminder-${reminderId}`
        });
        notifications.forEach((notification) => notification.close());
    } catch (error) {
        console.warn('Unable to clear scheduled notification.', error);
    }
};

const scheduleReminderTrigger = async (reminder) => {
    if (!supportsNotificationTriggers()) return false;
    if (!('Notification' in window)) return false;
    if (Notification.permission !== 'granted') return false;
    const dueTime = new Date(reminder.time).getTime();
    if (Number.isNaN(dueTime) || dueTime <= Date.now()) return false;
    try {
        const registration = await navigator.serviceWorker.ready;
        const options = {
            ...buildReminderNotificationOptions(reminder),
            showTrigger: new TimestampTrigger(dueTime)
        };
        await registration.showNotification(reminder.title || 'Reminder', options);
        return true;
    } catch (error) {
        console.warn('Unable to schedule background reminder.', error);
        return false;
    }
};

const schedulePendingReminderTriggers = async () => {
    if (reminderSchedulingInProgress) return;
    reminderSchedulingInProgress = true;
    try {
        if (!supportsNotificationTriggers()) return;
        const pending = reminders.filter(reminder => reminder.status === 'scheduled' && !reminder.triggerScheduled);
        for (const reminder of pending) {
            const scheduled = await scheduleReminderTrigger(reminder);
            if (scheduled) {
                reminder.triggerScheduled = true;
            }
        }
        saveReminders();
        renderReminders();
        updateNotificationStatus();
    } finally {
        reminderSchedulingInProgress = false;
    }
};

function normalizeReminderRecurrence(reminder) {
    const recurrence = reminder?.recurrence || {};
    const frequencyOptions = ['weekly', 'biweekly', 'monthly', 'none'];
    const frequency = frequencyOptions.includes(recurrence.frequency) ? recurrence.frequency : 'none';
    const daysOfWeek = Array.isArray(recurrence.daysOfWeek)
        ? recurrence.daysOfWeek.filter((day) => Number.isInteger(day) && day >= 0 && day <= 6)
        : [];
    const reminderDate = new Date(reminder?.time || Date.now());
    const defaultDayOfMonth = Number.isNaN(reminderDate.getTime()) ? 1 : reminderDate.getDate();
    const dayOfMonth = Number.isInteger(recurrence.dayOfMonth) ? recurrence.dayOfMonth : defaultDayOfMonth;
    const startDate = recurrence.startDate || reminder?.time || new Date().toISOString();
    return {
        frequency,
        daysOfWeek,
        dayOfMonth,
        startDate
    };
}

const isRecurringReminder = (reminder) => reminder?.recurrence?.frequency && reminder.recurrence.frequency !== 'none';

const getNextRecurringTime = (reminder, fromTime) => {
    const recurrence = normalizeReminderRecurrence(reminder);
    const baseDate = new Date(fromTime);
    if (Number.isNaN(baseDate.getTime())) return null;
    const hours = baseDate.getHours();
    const minutes = baseDate.getMinutes();
    if (recurrence.frequency === 'monthly') {
        const nextDate = new Date(baseDate);
        nextDate.setMonth(nextDate.getMonth() + 1);
        const daysInMonth = new Date(nextDate.getFullYear(), nextDate.getMonth() + 1, 0).getDate();
        const day = Math.min(recurrence.dayOfMonth || 1, daysInMonth);
        nextDate.setDate(day);
        nextDate.setHours(hours, minutes, 0, 0);
        return nextDate;
    }

    const allowedDays = recurrence.daysOfWeek?.length ? recurrence.daysOfWeek : [baseDate.getDay()];
    const startDate = new Date(recurrence.startDate || baseDate);
    startDate.setHours(0, 0, 0, 0);
    const maxDays = recurrence.frequency === 'biweekly' ? 14 : 7;
    for (let offset = 1; offset <= maxDays * 2; offset += 1) {
        const candidate = new Date(baseDate);
        candidate.setDate(candidate.getDate() + offset);
        candidate.setHours(hours, minutes, 0, 0);
        if (!allowedDays.includes(candidate.getDay())) continue;
        if (recurrence.frequency === 'biweekly') {
            const diffWeeks = Math.floor((candidate - startDate) / (7 * 24 * 60 * 60 * 1000));
            if (diffWeeks % 2 !== 0) continue;
        }
        return candidate;
    }
    return null;
};

const checkDueReminders = async () => {
    const now = Date.now();
    let updated = false;

    for (const reminder of reminders) {
        if (reminder.status !== 'scheduled') continue;
        const dueTime = new Date(reminder.time).getTime();
        if (Number.isNaN(dueTime)) {
            reminder.status = 'missed';
            updated = true;
            continue;
        }
        if (dueTime <= now) {
            if (reminder.triggerScheduled && supportsNotificationTriggers()) {
                if (isRecurringReminder(reminder)) {
                    const nextTime = getNextRecurringTime(reminder, reminder.time);
                    if (nextTime) {
                        reminder.time = nextTime.toISOString();
                        reminder.status = 'scheduled';
                        reminder.triggerScheduled = false;
                    } else {
                        reminder.status = 'sent';
                    }
                } else {
                    reminder.status = 'sent';
                }
                updated = true;
                continue;
            }

            const didSend = await sendReminderNotification(reminder);
            if (isRecurringReminder(reminder)) {
                const nextTime = getNextRecurringTime(reminder, reminder.time);
                if (nextTime) {
                    reminder.time = nextTime.toISOString();
                    reminder.status = 'scheduled';
                } else {
                    reminder.status = didSend ? 'sent' : 'missed';
                }
            } else {
                reminder.status = didSend ? 'sent' : 'missed';
            }
            updated = true;
        }
    }

    if (updated) {
        saveReminders();
        renderReminders();
    }
    if (updated) {
        await schedulePendingReminderTriggers();
    }
};

const addReminder = async () => {
    if (!reminderTitleInput || !reminderTimeInput) return;
    const title = reminderTitleInput.value.trim();
    const message = reminderMessageInput?.value.trim() || '';
    const timeValue = reminderTimeInput.value;
    if (!title || !timeValue) return;
    const scheduledDate = new Date(timeValue);
    if (Number.isNaN(scheduledDate.getTime())) {
        alert('Please choose a valid reminder time.');
        return;
    }
    if (scheduledDate.getTime() <= Date.now()) {
        alert('Please choose a time in the future.');
        return;
    }

    const recurrenceType = reminderRecurrenceSelect?.value || 'none';
    let recurrence = {
        frequency: 'none',
        daysOfWeek: [],
        dayOfMonth: scheduledDate.getDate(),
        startDate: scheduledDate.toISOString()
    };
    if (recurrenceType === 'weekly' || recurrenceType === 'biweekly') {
        const selectedDays = getSelectedWeekdays();
        if (!selectedDays.length) {
            alert('Select at least one weekday for recurring reminders.');
            return;
        }
        recurrence = {
            frequency: recurrenceType,
            daysOfWeek: selectedDays,
            dayOfMonth: scheduledDate.getDate(),
            startDate: scheduledDate.toISOString()
        };
    }
    if (recurrenceType === 'monthly') {
        const dayOfMonth = parseInt(reminderMonthlyDaySelect?.value, 10);
        recurrence = {
            frequency: 'monthly',
            daysOfWeek: [],
            dayOfMonth: Number.isInteger(dayOfMonth) ? dayOfMonth : scheduledDate.getDate(),
            startDate: scheduledDate.toISOString()
        };
    }

    const newReminder = {
        id: generateId(),
        title,
        message,
        time: scheduledDate.toISOString(),
        status: 'scheduled',
        createdAt: new Date().toISOString(),
        recurrence,
        triggerScheduled: false
    };
    reminders.push(newReminder);
    saveReminders();
    renderReminders();
    updateReminderTimeMin();
    reminderForm?.reset();
    updateRecurrenceFields();
    setMonthlyDayFromTime();
    const scheduled = await scheduleReminderTrigger(newReminder);
    if (scheduled) {
        newReminder.triggerScheduled = true;
        saveReminders();
        renderReminders();
    }
};

const updateTodoProgress = () => {
    if (!todoProgress) return;
    const completed = todos.filter(todo => todo.completed).length;
    todoProgress.textContent = `${completed} of ${todos.length} complete`;
};

const renderTodos = () => {
    if (!todoList) return;
    todoList.innerHTML = '';

    const filteredTodos = todoSearchQuery
        ? todos.filter(todo => {
            const text = (todo.text || '').toLowerCase();
            const matchesText = text.includes(todoSearchQuery);
            const matchesSubtask = Array.isArray(todo.subtasks)
                && todo.subtasks.some(subtask => (subtask.text || '').toLowerCase().includes(todoSearchQuery));
            return matchesText || matchesSubtask;
        })
        : todos;

    if (filteredTodos.length === 0) {
        const message = todos.length === 0
            ? 'No tasks yet'
            : 'No tasks match this search';
        todoList.innerHTML = `<li class="list-group-item text-center text-muted py-4">${message}</li>`;
        updateTodoProgress();
        return;
    }
    
    sortTodos(filteredTodos).forEach(todo => {
        const meta = TODO_PRIORITY_META[todo.priority] || TODO_PRIORITY_META.normal;
        const li = document.createElement('li');
        li.className = 'list-group-item';
        li.dataset.id = todo.id;
        const safeTodoText = escapeHtml(todo.text || '');
        const dueDateMarkup = todo.dueDate
            ? `<span class="todo-due-date"><i class="bi bi-calendar-event" aria-hidden="true"></i>Due ${escapeHtml(formatTodoDueDate(todo.dueDate))}</span>`
            : '';
        const priorityMarkup = `<span class="badge ${meta.className}"><i class="bi ${meta.icon} me-1" aria-hidden="true"></i>${meta.label}</span>`;

        const subtaskMarkup = todo.subtasks.length
            ? `<ul class="list-group list-group-flush small ms-4 mt-2">
                ${todo.subtasks.map(subtask => `
                    <li class="list-group-item d-flex justify-content-between align-items-center px-0">
                        <div class="d-flex align-items-center gap-2">
                            <input class="form-check-input" type="checkbox" data-role="subtodo-toggle" data-subtask-id="${subtask.id}" ${subtask.completed ? 'checked' : ''}>
                            <span class="${subtask.completed ? 'text-decoration-line-through text-muted' : ''}">${escapeHtml(subtask.text || '')}</span>
                        </div>
                        <button class="btn btn-sm btn-outline-danger" data-action="delete-subtask" data-subtask-id="${subtask.id}" aria-label="Delete subtask">
                            <i class="bi bi-x"></i>
                        </button>
                    </li>
                `).join('')}
            </ul>`
            : '';

        li.innerHTML = `
            <div class="flex-grow-1">
                <div class="todo-meta">
                    <input class="form-check-input me-2" type="checkbox" data-role="todo-toggle" ${todo.completed ? 'checked' : ''}>
                    <span class="${todo.completed ? 'text-decoration-line-through text-muted' : ''}">${safeTodoText}</span>
                    ${priorityMarkup}
                    ${dueDateMarkup}
                </div>
                ${subtaskMarkup}
            </div>
            <div class="todo-actions d-flex gap-2">
                <button class="btn btn-sm btn-outline-primary" data-action="add-subtask" aria-label="Add subtask">
                    <i class="bi bi-node-plus"></i>
                </button>
                <button class="btn btn-sm btn-outline-secondary" data-action="delete" aria-label="Delete task">
                    <i class="bi bi-trash"></i>
                </button>
            </div>
        `;
        todoList.appendChild(li);
    });
    
    updateTodoProgress();
};

const addTodo = (text, priority, dueDate = '') => {
    const todo = {
        id: Date.now(),
        text,
        priority,
        completed: false,
        createdAt: new Date().toISOString(),
        order: Math.min((todos.length + 1) * 10, MAX_ORDER_VALUE),
        subtasks: [],
        dueDate
    };
    todos.push(todo);
    saveTodos();
    renderTodos();
};

const toggleTodo = (id) => {
    todos = todos.map(todo => todo.id === id ? { ...todo, completed: !todo.completed } : todo);
    saveTodos();
    renderTodos();
};

const deleteTodo = (id) => {
    todos = todos.filter(todo => todo.id !== id);
    saveTodos();
    renderTodos();
};

const addSubtask = (todoId, text) => {
    if (!text) return;
    const newSubtask = {
        id: Date.now(),
        text,
        completed: false
    };
    todos = todos.map(todo => todo.id === todoId
        ? { ...todo, subtasks: [...todo.subtasks, newSubtask] }
        : todo
    );
    saveTodos();
    renderTodos();
};

const toggleSubtask = (todoId, subtaskId) => {
    todos = todos.map(todo => todo.id === todoId
        ? {
            ...todo,
            subtasks: todo.subtasks.map(subtask =>
                subtask.id === subtaskId ? { ...subtask, completed: !subtask.completed } : subtask
            )
        }
        : todo
    );
    saveTodos();
    renderTodos();
};

const deleteSubtask = (todoId, subtaskId) => {
    todos = todos.map(todo => todo.id === todoId
        ? { ...todo, subtasks: todo.subtasks.filter(subtask => subtask.id !== subtaskId) }
        : todo
    );
    saveTodos();
    renderTodos();
};

const saveShortcuts = () => {
    safeStorage.set(SHORTCUTS_STORAGE_KEY, JSON.stringify(shortcuts));
};

const seedShortcutsIfEmpty = () => {
    if (shortcuts.length || !DEFAULT_SHORTCUTS.length) return;
    shortcuts = DEFAULT_SHORTCUTS.map(item => ({
        ...item,
        createdAt: item.createdAt || new Date().toISOString()
    }));
    saveShortcuts();
};

const renderShortcuts = () => {
    if (!shortcutList) return;
    seedShortcutsIfEmpty();
    shortcutList.innerHTML = '';

    if (!shortcuts.length) {
        shortcutList.innerHTML = '<div class="text-center text-muted py-4">No shortcuts yet</div>';
        if (shortcutCount) shortcutCount.textContent = '0 saved';
        return;
    }

    shortcuts.forEach(shortcut => {
        const card = document.createElement('div');
        card.className = 'shortcut-card';
        card.dataset.shortcutId = shortcut.id;
        const safeTitle = escapeHtml(shortcut.title || 'Untitled');
        const safeDescription = escapeHtml(shortcut.description || '');
        const safeRoutine = escapeHtml(shortcut.routine || '');
        const safeLink = escapeHtml(shortcut.link || '');
        const routineMarkup = safeRoutine
            ? `<div class="shortcut-meta"><i class="bi bi-clock me-1"></i>${safeRoutine}</div>`
            : '';
        const linkMarkup = safeLink
            ? `<a class="btn btn-sm btn-outline-primary" href="${safeLink}" target="_blank" rel="noopener">
                    <i class="bi bi-box-arrow-up-right me-1"></i> Open
               </a>`
            : '<span class="badge text-bg-light">No link yet</span>';

        card.innerHTML = `
            <div class="shortcut-card-header">
                <div>
                    <div class="fw-semibold">${safeTitle}</div>
                    ${routineMarkup}
                </div>
                <button class="btn btn-sm btn-outline-danger" data-action="delete-shortcut" aria-label="Delete shortcut">
                    <i class="bi bi-trash"></i>
                </button>
            </div>
            <div>${safeDescription || '<span class="text-muted">Add notes to remember what this shortcut does.</span>'}</div>
            <div class="shortcut-actions">
                ${linkMarkup}
            </div>
        `;
        shortcutList.appendChild(card);
    });

    if (shortcutCount) {
        shortcutCount.textContent = `${shortcuts.length} saved`;
    }
};

const addShortcut = (title, description, routine, link) => {
    const trimmedTitle = title.trim();
    if (!trimmedTitle) return;
    const newShortcut = {
        id: `shortcut-${generateId()}`,
        title: trimmedTitle,
        description: description.trim(),
        routine: routine.trim(),
        link: link.trim(),
        createdAt: new Date().toISOString()
    };
    shortcuts = [newShortcut, ...shortcuts];
    saveShortcuts();
    renderShortcuts();
};

const deleteShortcut = (id) => {
    shortcuts = shortcuts.filter(shortcut => shortcut.id !== id);
    saveShortcuts();
    renderShortcuts();
};

const getSharedBalances = () => {
    const balances = {};
    sharedParticipants.forEach(participant => { balances[participant.id] = 0; });
    sharedExpenses.forEach(expense => {
        const participants = expense.participantIds.length ? expense.participantIds : sharedParticipants.map(p => p.id);
        const share = participants.length ? expense.amount / participants.length : 0;
        participants.forEach(id => {
            if (id === expense.payerId) {
                balances[id] += expense.amount - share;
            } else {
                balances[id] -= share;
            }
        });
    });
    return balances;
};

const updateSharedExpenseControls = () => {
    if (!sharedExpensePayer || !sharedExpenseParticipants) return;
    sharedExpensePayer.innerHTML = sharedParticipants
        .map(participant => `<option value="${participant.id}">${escapeHtml(participant.name || '')}</option>`)
        .join('');
    
    sharedExpenseParticipants.innerHTML = sharedParticipants
        .map(participant => `
            <label class="form-check form-check-inline d-flex align-items-center gap-1">
                <input class="form-check-input" type="checkbox" value="${participant.id}" checked>
                <span>${escapeHtml(participant.name || '')}</span>
            </label>
        `).join('');
};

const renderSharedParticipants = () => {
    if (!sharedParticipantList) return;
    const balances = getSharedBalances();
    
    if (!sharedParticipants.length) {
        sharedParticipantList.innerHTML = '<li class="text-muted">Add someone to get started</li>';
        return;
    }
    
    sharedParticipantList.innerHTML = sharedParticipants
        .map(participant => {
            const balance = balances[participant.id] || 0;
            const balanceClass = balance >= 0 ? 'text-success' : 'text-danger';
            const safeName = escapeHtml(participant.name || '');
            return `
                <li class="shared-balance" data-id="${participant.id}">
                    <strong>${safeName}</strong>
                    <div class="d-flex align-items-center gap-2">
                        <span class="${balanceClass}">${formatCurrency(balance, { includePlus: true })}</span>
                        <button class="btn btn-sm btn-outline-danger" data-shared-action="delete-participant" aria-label="Remove participant">
                            <i class="bi bi-x"></i>
                        </button>
                    </div>
                </li>
            `;
        })
        .join('');
};

const renderSharedExpenseHistory = () => {
    if (!sharedExpenseHistory) return;
    if (!sharedExpenses.length) {
        sharedExpenseHistory.innerHTML = '<li class="list-group-item text-center text-muted py-4">No shared expenses yet</li>';
        sharedExpenseSummary.textContent = 'No expenses yet';
        return;
    }
    
    const total = sharedExpenses.reduce((sum, expense) => sum + expense.amount, 0);
    sharedExpenseSummary.textContent = `${sharedExpenses.length} expenses · ${formatCurrency(total)}`;
    
    sharedExpenseHistory.innerHTML = sharedExpenses
        .slice()
        .sort((a, b) => new Date(b.date) - new Date(a.date))
        .map(expense => {
            const payer = sharedParticipants.find(p => p.id === expense.payerId);
            const participants = expense.participantIds
                .map(id => escapeHtml(sharedParticipants.find(p => p.id === id)?.name || 'Unknown'))
                .join(', ');
            const safeDescription = escapeHtml(expense.description || '');
            const safePayerName = escapeHtml(payer?.name || 'Unknown');
            return `
                <li class="list-group-item" data-id="${expense.id}">
                    <div>
                        <div class="fw-semibold">${safeDescription}</div>
                        <div class="text-muted small">Paid by ${safePayerName} · Split with ${participants}</div>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <span class="shared-expense-chip">${formatCurrency(expense.amount)}</span>
                        <button class="btn btn-sm btn-outline-danger" data-shared-action="delete-expense" aria-label="Delete shared expense">
                            <i class="bi bi-trash"></i>
                        </button>
                    </div>
                </li>
            `;
        })
        .join('');
};

const buildSplitSummary = () => {
    if (!sharedParticipants.length) return 'No participants yet.';
    const balances = getSharedBalances();
    const lines = sharedParticipants.map(participant => {
        const balance = balances[participant.id] || 0;
        const label = balance >= 0 ? 'is owed' : 'owes';
        return `${participant.name}: ${label} ${formatCurrency(balance, { includePlus: true })}`;
    });
    const totalExpenses = sharedExpenses.reduce((sum, expense) => sum + expense.amount, 0);
    return [
        'One Place split summary',
        `Total shared expenses: ${formatCurrency(totalExpenses)}`,
        ...lines
    ].join('\n');
};

const copySplitSummary = async () => {
    const summary = buildSplitSummary();
    if (!navigator.clipboard) {
        alert(summary);
        return;
    }
    try {
        await navigator.clipboard.writeText(summary);
        alert('Split summary copied to clipboard.');
    } catch (error) {
        alert(summary);
    }
};

const addSharedParticipant = (name) => {
    if (!name) return;
    sharedParticipants.push({ id: generateId(), name });
    saveSharedParticipants();
    updateSharedExpenseControls();
    renderSharedParticipants();
};

const deleteSharedParticipant = (participantId) => {
    const hasExpenses = sharedExpenses.some(expense => expense.payerId === participantId || expense.participantIds.includes(participantId));
    if (hasExpenses) {
        alert('Please delete expenses involving this person before removing them.');
        return;
    }
    sharedParticipants = sharedParticipants.filter(participant => participant.id !== participantId);
    saveSharedParticipants();
    updateSharedExpenseControls();
    renderSharedParticipants();
};

const addSharedExpense = (description, amount, payerId, participantIds) => {
    const expenseParticipants = participantIds.length ? participantIds : sharedParticipants.map(p => p.id);
    if (!expenseParticipants.includes(payerId)) {
        expenseParticipants.push(payerId);
    }
    sharedExpenses.push({
        id: generateId(),
        description,
        amount,
        payerId,
        participantIds: expenseParticipants,
        date: new Date().toISOString()
    });
    saveSharedExpenses();
    renderSharedExpenseHistory();
    renderSharedParticipants();
};

const resetSharedExpenses = () => {
    sharedExpenses = [];
    saveSharedExpenses();
    renderSharedExpenseHistory();
    renderSharedParticipants();
};

const renderCategoryPills = () => {
    if (!categoryPillGroup) return;
    categoryPillGroup.innerHTML = '';
    const categories = getAllCategories();

    categories.forEach(category => {
        const pill = document.createElement('button');
        pill.type = 'button';
        pill.className = 'category-pill';
        pill.dataset.value = category.value;
        pill.dataset.color = category.color;
        pill.dataset.type = category.type;
        pill.title = category.label;
        pill.setAttribute('aria-pressed', 'false');
        pill.setAttribute('aria-label', `${category.label} category`);
        pill.style.backgroundColor = hexToRgba(category.color, 0.08);
        pill.style.color = category.color;
        const icon = document.createElement('span');
        icon.className = 'pill-icon bi bi-check2-circle';
        icon.setAttribute('aria-hidden', 'true');
        const label = document.createElement('span');
        label.className = 'pill-label';
        label.textContent = category.label;
        const status = document.createElement('span');
        status.className = 'visually-hidden pill-status';
        pill.append(icon, label, status);
        categoryPillGroup.appendChild(pill);
    });
    
    const currentCategory = categorySelect ? categorySelect.value : '';
    setActiveCategory(currentCategory || null);
};

const renderCategoryOptions = () => {
    if (!categorySelect) return;
    categorySelect.innerHTML = '';

    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.textContent = 'Choose a category';
    categorySelect.appendChild(placeholder);

    const categories = getAllCategories();
    categories.forEach(category => {
        const option = document.createElement('option');
        option.value = category.value;
        option.textContent = category.label;
        categorySelect.appendChild(option);
    });
};

const renderCategoryFilters = () => {
    if (!categoryFilter) return;
    categoryFilter.innerHTML = '';
    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.textContent = 'All Categories';
    categoryFilter.appendChild(placeholder);

    const categories = getAllCategories();
    const incomeGroup = document.createElement('optgroup');
    incomeGroup.label = 'Income';
    const expenseGroup = document.createElement('optgroup');
    expenseGroup.label = 'Expenses';

    categories.forEach(category => {
        const option = document.createElement('option');
        option.value = category.value;
        option.textContent = category.label;
        if (category.type === 'income') {
            incomeGroup.appendChild(option);
        } else {
            expenseGroup.appendChild(option);
        }
    });

    if (incomeGroup.children.length) categoryFilter.appendChild(incomeGroup);
    if (expenseGroup.children.length) categoryFilter.appendChild(expenseGroup);
    if (activeCategoryFilter) {
        categoryFilter.value = activeCategoryFilter;
    }
};

const saveCustomCategories = () => {
    safeStorage.set(CUSTOM_CATEGORIES_KEY, JSON.stringify(customCategories));
};

const generateCategoryValue = (label) => label
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');

const getNextCustomCategoryColor = () => {
    const palette = ['#0d6efd', '#20c997', '#6f42c1', '#fd7e14', '#dc3545', '#198754'];
    return palette[customCategories.length % palette.length];
};

const addCustomCategory = () => {
    if (!customCategoryNameInput || !customCategoryTypeSelect) return;
    const label = customCategoryNameInput.value.trim();
    const type = customCategoryTypeSelect.value === 'income' ? 'income' : 'expense';
    if (!label) return;
    const value = generateCategoryValue(label);
    if (CATEGORY_LOOKUP[value]) {
        alert('That category already exists.');
        return;
    }
    const color = getNextCustomCategoryColor();
    customCategories.push({ value, label, type, color });
    saveCustomCategories();
    CATEGORY_LOOKUP = buildCategoryLookup(getAllCategories());
    renderCategoryOptions();
    renderCategoryPills();
    renderCategoryFilters();
    customCategoryNameInput.value = '';
    setActiveCategory(value);
};

const setActiveCategory = (categoryValue) => {
    categoryPillGroup?.querySelectorAll('.category-pill').forEach(pill => {
        const isActive = pill.dataset.value === categoryValue;
        pill.classList.toggle('active', isActive);
        pill.style.backgroundColor = isActive 
            ? pill.dataset.color 
            : hexToRgba(pill.dataset.color, 0.08);
        pill.style.color = isActive ? '#ffffff' : pill.dataset.color;
        if (isActive) {
            pill.style.borderColor = pill.dataset.color;
        } else {
            pill.style.borderColor = 'transparent';
        }
        pill.setAttribute('aria-pressed', isActive ? 'true' : 'false');
        const status = pill.querySelector('.pill-status');
        if (status) status.textContent = isActive ? 'Selected' : '';
    });
    
    if (categorySelect) {
        categorySelect.value = categoryValue || '';
    }
    updateCategoryHint(categoryValue);
    
    const config = getCategoryConfig(categoryValue);
    if (config) {
        document.getElementById(config.type === 'income' ? 'incomeRadio' : 'expenseRadio').checked = true;
    }
};

const updateCategoryHint = (categoryValue) => {
    if (!categoryHint || !categoryGuidance) return;
    
    if (!categoryValue) {
        categoryHint.textContent = DEFAULT_CATEGORY_HINT;
        categoryGuidance.textContent = DEFAULT_GUIDANCE;
        return;
    }
    
    const config = getCategoryConfig(categoryValue);
    categoryHint.textContent = config?.hint || DEFAULT_CATEGORY_HINT;
    categoryGuidance.textContent = config?.type === 'income'
        ? 'Great! Gains add to your balance.'
        : 'Heads up: owes reduce your balance.';
};

const applyTheme = (mode) => {
    const resolvedMode = mode === 'auto'
        ? (prefersDarkScheme.matches ? 'dark' : 'light')
        : mode;
    document.body.classList.toggle('dark-mode', resolvedMode === 'dark');
};

const applyAccent = (color) => {
    if (!color) return;
    document.documentElement.style.setProperty('--primary-color', color);
    document.documentElement.style.setProperty('--accent-color', color);
    document.documentElement.style.setProperty('--accent-color-soft', hexToRgba(color, 0.15));
};

const setAccent = (color) => {
    safeStorage.set(ACCENT_STORAGE_KEY, color);
    applyAccent(color);
    accentOptionsContainer?.querySelectorAll('.accent-swatch').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.accent === color);
    });
};

const updateThemeButtons = (mode) => {
    themeModeButtons.forEach((button) => {
        const isActive = button.dataset.themeMode === mode;
        button.classList.toggle('active', isActive);
        button.setAttribute('aria-pressed', isActive ? 'true' : 'false');
    });
};

const setThemeMode = (mode) => {
    safeStorage.set(THEME_STORAGE_KEY, mode);
    applyTheme(mode);
    updateThemeButtons(mode);
};

const initializeThemeControls = () => {
    const savedTheme = safeStorage.get(THEME_STORAGE_KEY) || 'auto';
    updateThemeButtons(savedTheme);
    applyTheme(savedTheme);
    
    const savedAccent = safeStorage.get(ACCENT_STORAGE_KEY) || '#0d6efd';
    setAccent(savedAccent);
};

const handleSystemThemeChange = () => {
    if ((safeStorage.get(THEME_STORAGE_KEY) || 'auto') === 'auto') {
        applyTheme('auto');
    }
};

if (prefersDarkScheme.addEventListener) {
    prefersDarkScheme.addEventListener('change', handleSystemThemeChange);
} else if (prefersDarkScheme.addListener) {
    prefersDarkScheme.addListener(handleSystemThemeChange);
}

// Transaction Management
function addTransaction(e) {
    if (e) e.preventDefault();
    
    const description = descriptionInput.value.trim();
    const amount = parseFloat(amountInput.value);
    const type = document.querySelector('input[name="transactionType"]:checked').value;
    const category = categorySelect.value;
    const urgency = DEFAULT_URGENCY;
    
    if (!description) {
        showAlert('Please enter a description', 'warning');
        return;
    }
    
    if (isNaN(amount) || amount <= 0) {
        showAlert('Please enter a valid amount greater than 0', 'warning');
        return;
    }

    if (!category) {
        showAlert('Please choose a category', 'warning');
        return;
    }
    
    const transaction = {
        id: Date.now(),
        description,
        amount: Math.abs(amount),
        type,
        category,
        urgency,
        date: new Date().toISOString()
    };

    transactions.push(transaction);
    saveTransactions();

    descriptionInput.value = '';
    amountInput.value = '';
    document.getElementById('incomeRadio').checked = true;
    setActiveCategory(null);
    editTransactionId = null;
    addTransactionButton.style.display = 'block';
    saveTransactionButton.style.display = 'none';

    updateBalance();
    displayTransactions();
}

function createTransactionElement(transaction) {
    const li = document.createElement('li');
    li.className = 'list-group-item';
    li.dataset.id = transaction.id;
    li.dataset.transaction = 'true';

    const normalizedAmount = Math.abs(transaction.amount);
    const signedAmount = transaction.type === 'income'
        ? normalizedAmount
        : -normalizedAmount;
    const transactionAmount = formatCurrency(signedAmount, { includePlus: true });

    const categoryColor = getCategoryColor(transaction.category);
    const categoryName = getCategoryName(transaction.category);
    const transactionDate = new Date(transaction.date || transaction.dateModified || transaction.id);
    const safeDescription = escapeHtml(transaction.description || '');
    const safeCategoryName = escapeHtml(categoryName);
    const urgencyOptions = URGENCY_OPTIONS.map(option => `
                        <option value="${option.value}" ${option.value === transaction.urgency ? 'selected' : ''}>
                            ${escapeHtml(option.label)}
                        </option>
                    `).join('');

    li.innerHTML = `
        <div class="transaction-details">
            <div class="transaction-info">
                <div class="fw-bold">${safeDescription}</div>
                <div class="transaction-meta">
                    <span class="category-badge" style="background-color: ${categoryColor}">${safeCategoryName}</span>
                    <select class="form-select form-select-sm urgency-select" aria-label="Update urgency">
                        ${urgencyOptions}
                    </select>
                    <span>${transactionDate.toLocaleDateString()}</span>
                </div>
            </div>
            <div class="transaction-actions d-flex gap-2 align-items-center">
                <span class="${transaction.type === 'income' ? 'positive' : 'negative'} fw-bold">${transactionAmount}</span>
                <button class="btn btn-sm btn-outline-primary edit-btn" aria-label="Edit transaction">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger delete-btn" aria-label="Delete transaction">
                    <i class="bi bi-trash"></i>
                </button>
            </div>
        </div>
    `;

    return li;
}

function displayTransactions(list) {
    historyList.innerHTML = '';
    const data = Array.isArray(list) ? list : getFilteredTransactions();
    
    if (data.length === 0) {
        const message = transactions.length === 0 
            ? 'No transactions yet'
            : 'No transactions match this view';
        historyList.innerHTML = `<li class="list-group-item text-center py-4 text-muted">${message}</li>`;
    } else {
        const grouped = data.reduce((acc, transaction) => {
            const sourceDate = transaction.date || transaction.dateModified || new Date().toISOString();
            const dateKey = getLocalDateKey(sourceDate) || sourceDate.split('T')[0];
            const localDate = getLocalDateFromKey(dateKey);
            const timestamp = localDate.getTime();

            if (!acc[dateKey]) {
                acc[dateKey] = { label: formatGroupLabel(dateKey), timestamp, items: [] };
            }

            acc[dateKey].items.push(transaction);
            return acc;
        }, {});
        
        Object.values(grouped)
            .sort((a, b) => b.timestamp - a.timestamp)
            .forEach(group => {
                const header = document.createElement('li');
                header.className = 'list-group-item group-header';
                header.textContent = group.label;
                historyList.appendChild(header);
                
                group.items
                    .sort((a, b) => {
                        const urgencyDiff = getUrgencySortValue(a.urgency) - getUrgencySortValue(b.urgency);
                        if (urgencyDiff !== 0) return urgencyDiff;
                        return getTransactionSortTimestamp(b) - getTransactionSortTimestamp(a);
                    })
                    .forEach(transaction => {
                        const element = createTransactionElement(transaction);
                        historyList.appendChild(element);
                    });
            });
    }

    const hasTransactions = transactions.length > 0;
    if (!hasTransactions) {
        historySection.style.display = 'none';
        toggleHistoryButton.innerHTML = '<i class="bi bi-chevron-down"></i> Show';
        toggleHistoryButton.setAttribute('aria-expanded', 'false');
        delete historySection.dataset.userToggled;
        return;
    }

    if (historySection.dataset.userToggled !== 'true') {
        historySection.style.display = 'block';
        toggleHistoryButton.innerHTML = '<i class="bi bi-chevron-up"></i> Hide';
        toggleHistoryButton.setAttribute('aria-expanded', 'true');
        return;
    }

    const isHidden = historySection.style.display === 'none';
    toggleHistoryButton.innerHTML = `<i class="bi bi-chevron-${isHidden ? 'down' : 'up'}"></i> ${isHidden ? 'Show' : 'Hide'}`;
    toggleHistoryButton.setAttribute('aria-expanded', isHidden ? 'false' : 'true');
}

const parseTransactionDate = (transaction) => {
    const source = transaction.date || transaction.dateModified || transaction.id;
    return new Date(source);
};

const getLocalDateKey = (source) => {
    const date = new Date(source);
    if (Number.isNaN(date.getTime())) return '';
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
};

const getLocalDateFromKey = (key) => {
    if (!key) return new Date();
    const [year, month, day] = key.split('-').map(Number);
    if (!year || !month || !day) return new Date();
    return new Date(year, month - 1, day);
};

const getTransactionSortTimestamp = (transaction) => {
    const source = transaction.dateModified || transaction.date || transaction.id;
    return new Date(source).getTime();
};

const formatGroupLabel = (dateKey) => {
    const target = getLocalDateFromKey(dateKey);
    const today = new Date();
    const yesterday = new Date();
    yesterday.setDate(today.getDate() - 1);

    if (isSameDay(target, today)) return 'Today';
    if (isSameDay(target, yesterday)) return 'Yesterday';

    return target.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
};

const isSameDay = (a, b) => 
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();

function deleteTransaction(id) {
    transactions = transactions.filter(t => t.id !== id);
    saveTransactions();
    
    updateBalance();
    displayTransactions();
}

function saveTransactions() {
    safeStorage.set('transactions', JSON.stringify(transactions));
}

function updateTransactionUrgency(id, value) {
    const transaction = transactions.find(item => item.id === id);
    if (!transaction) return;
    transaction.urgency = normalizeUrgencyValue(value);
    transaction.dateModified = new Date().toISOString();
    saveTransactions();
    displayTransactions();
    updateBalance();
}

function startEdit(transaction) {
    descriptionInput.value = transaction.description;
    amountInput.value = Math.abs(transaction.amount);
    categorySelect.value = transaction.category;
    setActiveCategory(transaction.category);
    document.querySelector(`input[value="${transaction.type}"]`).checked = true;
    if (urgencySelect) {
        urgencySelect.value = normalizeUrgencyValue(transaction.urgency);
    }
    
    addTransactionButton.style.display = 'none';
    saveTransactionButton.style.display = 'block';
    editTransactionId = transaction.id;
}

function saveEdit(e) {
    e.preventDefault();
    
    if (editTransactionId === null) return;
    const transactionIndex = transactions.findIndex(t => t.id === editTransactionId);
    
    if (transactionIndex === -1) return;
    
    const description = descriptionInput.value.trim();
    const amount = parseFloat(amountInput.value);
    const type = document.querySelector('input[name="transactionType"]:checked').value;
    const category = categorySelect.value;
    const urgency = normalizeUrgencyValue(transactions[transactionIndex].urgency);

    if (!description) {
        showAlert('Please enter a description', 'warning');
        return;
    }

    if (isNaN(amount) || amount <= 0) {
        showAlert('Please enter a valid amount greater than 0', 'warning');
        return;
    }

    if (!category) {
        showAlert('Please choose a category', 'warning');
        return;
    }
    
    transactions[transactionIndex] = {
        ...transactions[transactionIndex],
        description,
        amount: Math.abs(amount),
        type,
        category,
        urgency,
        date: new Date().toISOString()
    };
    
    saveTransactions();
    
    descriptionInput.value = '';
    amountInput.value = '';
    document.getElementById('incomeRadio').checked = true;
    setActiveCategory(null);
    
    addTransactionButton.style.display = 'block';
    saveTransactionButton.style.display = 'none';
    editTransactionId = null;
    
    updateBalance();
    displayTransactions();
}

function updateBalance() {
    const filteredList = getFilteredTransactions();
    const totalNet = calculateNet(transactions);
    const filteredNet = calculateNet(filteredList);
    const isFiltered = Boolean(activeCategoryFilter || activeUrgencyFilter);
    const valueToShow = isFiltered ? filteredNet : totalNet;
    
    balanceElement.textContent = formatCurrency(valueToShow);
    balanceElement.className = `balance-display fs-2 fw-bold ${valueToShow >= 0 ? 'positive' : 'negative'}`;
    
    if (balanceScope) {
        balanceScope.textContent = isFiltered
            ? `${getFilterLabel()} · ${formatCurrency(filteredNet)}`
            : `All categories · ${formatCurrency(totalNet)}`;
    }
    
    updateCategoryBalanceIndicator(filteredList);
    updateInsights();
}

function updateCategoryBalanceIndicator(list = []) {
    if (!categoryBalanceIndicator) return;
    const label = getFilterLabel();
    const net = calculateNet(list);
    const formatted = formatCurrency(net, { includePlus: true });
    categoryBalanceIndicator.textContent = `${label} · Balance ${formatted}`;
    categoryBalanceIndicator.classList.toggle('text-success', net >= 0);
    categoryBalanceIndicator.classList.toggle('text-danger', net < 0);
}

const getWeekStartDate = (date) => {
    const start = new Date(date);
    const day = start.getDay();
    start.setDate(start.getDate() - day);
    start.setHours(0, 0, 0, 0);
    return start;
};

const formatWeekLabel = (startDate) => {
    const endDate = new Date(startDate);
    endDate.setDate(startDate.getDate() + 6);
    const startLabel = startDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
    const endLabel = endDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
    return `${startLabel}–${endLabel}`;
};

const renderSpendingTrend = () => {
    if (!spendingTrend) return;
    const now = new Date();
    const startOfWeek = getWeekStartDate(now);
    const weeks = Array.from({ length: 6 }, (_, index) => {
        const start = new Date(startOfWeek);
        start.setDate(startOfWeek.getDate() - (5 - index) * 7);
        return start;
    });

    const totals = weeks.map(weekStart => {
        const weekEnd = new Date(weekStart);
        weekEnd.setDate(weekStart.getDate() + 6);
        const total = transactions
            .filter(t => t.type === 'expense')
            .filter(t => {
                const date = parseTransactionDate(t);
                return date >= weekStart && date <= weekEnd;
            })
            .reduce((sum, t) => sum + Math.abs(t.amount), 0);
        return { weekStart, total };
    });

    const maxTotal = Math.max(...totals.map(item => item.total), 0);
    spendingTrend.innerHTML = '';

    if (!maxTotal) {
        spendingTrend.innerHTML = '<div class="text-muted">No spending data yet.</div>';
        return;
    }

    totals.forEach(({ weekStart, total }) => {
        const item = document.createElement('div');
        item.className = 'trend-item';
        item.setAttribute('role', 'listitem');
        const percentage = maxTotal ? Math.max((total / maxTotal) * 100, 6) : 0;
        item.innerHTML = `
            <div class="trend-label">${formatWeekLabel(weekStart)}</div>
            <div class="trend-bar" aria-hidden="true">
                <div class="trend-bar-fill" style="width: ${percentage}%;"></div>
            </div>
            <div class="trend-amount">${formatCurrency(-total)}</div>
        `;
        spendingTrend.appendChild(item);
    });
};

function updateInsights() {
    if (!insightIncome || !insightExpense || !insightTopCategory || !insightRecent || !insightTopCategoryAmount) {
        renderSpendingTrend();
        return;
    }
    
    const totalIncome = transactions
        .filter(t => t.type === 'income')
        .reduce((sum, transaction) => sum + Math.abs(transaction.amount), 0);
    const totalExpense = transactions
        .filter(t => t.type === 'expense')
        .reduce((sum, transaction) => sum + Math.abs(transaction.amount), 0);
    
    insightIncome.textContent = formatCurrency(totalIncome);
    insightExpense.textContent = formatCurrency(-totalExpense);
    
    const expenseByCategory = transactions
        .filter(t => t.type === 'expense')
        .reduce((acc, transaction) => {
            acc[transaction.category] = (acc[transaction.category] || 0) + Math.abs(transaction.amount);
            return acc;
        }, {});
    
    const topCategoryEntry = Object.entries(expenseByCategory)
        .sort((a, b) => b[1] - a[1])[0];
    
    if (topCategoryEntry) {
        insightTopCategory.textContent = getCategoryName(topCategoryEntry[0]);
        insightTopCategoryAmount.textContent = formatCurrency(-topCategoryEntry[1]);
    } else {
        insightTopCategory.textContent = 'No data yet';
        insightTopCategoryAmount.textContent = formatCurrency(0);
    }
    
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setHours(0, 0, 0, 0);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
    
    const recentExpense = transactions
        .filter(t => t.type === 'expense')
        .filter(t => parseTransactionDate(t) >= sevenDaysAgo)
        .reduce((sum, t) => sum + Math.abs(t.amount), 0);
    
    insightRecent.textContent = formatCurrency(-recentExpense);
    renderSpendingTrend();
}

function exportToCSV() {
    if (transactions.length === 0) {
        alert('No transactions to export');
        return;
    }
    
    const csvContent = [
        ['Date', 'Description', 'Category', 'Urgency', 'Type', 'Amount'],
        ...transactions.map(t => [
            parseTransactionDate(t).toLocaleDateString(),
            t.description,
            getCategoryName(t.category),
            getUrgencyLabel(t.urgency),
            t.type,
            t.type === 'income' ? Math.abs(t.amount) : -Math.abs(t.amount)
        ])
    ]
        .map(row => row.map(cell => escapeCsvCell(cell)).join(','))
        .join('\n');
    
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `transactions_${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
}

const parseCsvRow = (row) => {
    const output = [];
    let current = '';
    let inQuotes = false;
    for (let i = 0; i < row.length; i += 1) {
        const char = row[i];
        const nextChar = row[i + 1];
        if (char === '"' && inQuotes && nextChar === '"') {
            current += '"';
            i += 1;
        } else if (char === '"') {
            inQuotes = !inQuotes;
        } else if (char === ',' && !inQuotes) {
            output.push(current);
            current = '';
        } else {
            current += char;
        }
    }
    output.push(current);
    return output.map((cell) => cell.trim());
};

const findCategoryValue = (label = '', type = '') => {
    const normalizedLabel = label.toLowerCase();
    const categories = getAllCategories();
    const match = categories.find((category) =>
        category.value.toLowerCase() === normalizedLabel
        || category.label.toLowerCase() === normalizedLabel
    );
    if (match) return match.value;
    if (!label) return '';
    const value = generateCategoryValue(label);
    const color = getNextCustomCategoryColor();
    const normalizedType = type === 'income' ? 'income' : 'expense';
    customCategories.push({ value, label, type: normalizedType, color });
    saveCustomCategories();
    CATEGORY_LOOKUP = buildCategoryLookup(getAllCategories());
    renderCategoryOptions();
    renderCategoryPills();
    renderCategoryFilters();
    return value;
};

const importTransactionsFromCsv = (text) => {
    const lines = text.split(/\r?\n/).filter((line) => line.trim());
    if (!lines.length) return;
    const header = parseCsvRow(lines[0]).map((value) => value.toLowerCase());
    const hasHeader = header.includes('date') || header.includes('description');
    const startIndex = hasHeader ? 1 : 0;

    const getValue = (row, key, index) => {
        if (hasHeader) {
            const keyIndex = header.indexOf(key);
            return keyIndex >= 0 ? row[keyIndex] : '';
        }
        return row[index] || '';
    };

    for (let i = startIndex; i < lines.length; i += 1) {
        const row = parseCsvRow(lines[i]);
        const description = getValue(row, 'description', 1);
        const categoryLabel = getValue(row, 'category', 2);
        const urgency = normalizeUrgencyValue(getValue(row, 'urgency', 3));
        const typeRaw = getValue(row, 'type', 4).toLowerCase();
        const amountRaw = parseFloat(getValue(row, 'amount', 5));
        const type = typeRaw === 'income' || typeRaw === 'expense'
            ? typeRaw
            : amountRaw < 0
                ? 'expense'
                : 'income';
        const categoryValue = findCategoryValue(categoryLabel, type);
        const dateValue = getValue(row, 'date', 0);
        const parsedDate = new Date(dateValue);
        const date = Number.isNaN(parsedDate.getTime()) ? new Date().toISOString() : parsedDate.toISOString();

        const transaction = normalizeTransaction({
            id: generateId(),
            description,
            amount: Math.abs(amountRaw || 0),
            type,
            category: categoryValue,
            urgency,
            date
        });
        transactions.push(transaction);
    }
    saveTransactions();
    updateBalance();
    displayTransactions();
};

const exportFullBackup = () => {
    const payload = {
        exportedAt: new Date().toISOString(),
        transactions,
        todos,
        sharedParticipants,
        sharedExpenses,
        communicationItems,
        customCategories
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `oneplace_backup_${new Date().toISOString().split('T')[0]}.json`;
    link.click();
};

const importBackupData = (data) => {
    if (!data) return;
    if (Array.isArray(data)) {
        data.forEach((item, index) => {
            const transaction = normalizeTransaction(item, index);
            transactions.push(transaction);
        });
    } else if (typeof data === 'object') {
        if (Array.isArray(data.customCategories)) {
            customCategories = normalizeCustomCategories(data.customCategories);
            saveCustomCategories();
            CATEGORY_LOOKUP = buildCategoryLookup(getAllCategories());
        }
        if (Array.isArray(data.transactions)) {
            transactions = data.transactions.map((item, index) => normalizeTransaction(item, index));
            saveTransactions();
        }
        if (Array.isArray(data.todos)) {
            todos = data.todos.map((item, index) => normalizeTodo(item, index));
            saveTodos();
        }
        if (Array.isArray(data.sharedParticipants)) {
            sharedParticipants = data.sharedParticipants;
            saveSharedParticipants();
        }
        if (Array.isArray(data.sharedExpenses)) {
            sharedExpenses = data.sharedExpenses;
            saveSharedExpenses();
        }
        if (Array.isArray(data.communicationItems)) {
            communicationItems = data.communicationItems;
            saveCommunicationItems();
        }
    }
    renderCategoryOptions();
    renderCategoryPills();
    renderCategoryFilters();
    renderTodos();
    renderSharedParticipants();
    renderSharedExpenseHistory();
    normalizeCommunicationItems();
    renderCommunicationItems();
    updateBalance();
    displayTransactions();
};

function showAlert(message, type = 'warning') {
    const alert = document.createElement('div');
    alert.className = `alert alert-${type} alert-dismissible fade show position-fixed top-0 start-50 translate-middle-x mt-3`;
    alert.style.zIndex = '1000';
    alert.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    document.body.appendChild(alert);
    
    setTimeout(() => {
        alert.classList.remove('show');
        setTimeout(() => alert.remove(), 150);
    }, 3000);
}

// Communication helper functions
const saveCommunicationItems = () => {
    safeStorage.set(COMMUNICATION_ITEMS_KEY, JSON.stringify(communicationItems));
};

const nextCommunicationColor = (index) => {
    const palette = ['#0d6efd', '#20c997', '#fd7e14', '#e83e8c', '#6f42c1'];
    return palette[index % palette.length];
};

const normalizeCommunicationItems = () => {
    communicationItems = communicationItems.map((item, index) => {
        const { voiceId, ...rest } = item;
        return {
            ...rest,
            phrase: item.phrase || '',
            lang: item.lang || 'en',
            audioData: item.audioData || '',
            color: rest.color || nextCommunicationColor(index),
            emoji: normalizeEmojiValue(rest.emoji || rest.title?.charAt(0) || '')
        };
    });
    saveCommunicationItems();
};

const setRecordingStatus = (message, tone = 'muted') => {
    if (!communicationRecordingStatus) return;
    communicationRecordingStatus.textContent = message;
    communicationRecordingStatus.classList.toggle('text-danger', tone === 'error');
    communicationRecordingStatus.classList.toggle('text-success', tone === 'success');
    communicationRecordingStatus.classList.toggle('text-muted', tone === 'muted');
};

const updateRecordingButton = (isRecording = false) => {
    if (!communicationRecordButton) return;
    communicationRecordButton.innerHTML = isRecording
        ? '<i class="bi bi-stop-circle"></i> Stop recording'
        : '<i class="bi bi-mic"></i> Start recording';
    communicationRecordButton.classList.toggle('btn-danger', isRecording);
    communicationRecordButton.classList.toggle('btn-outline-primary', !isRecording);
};

const resetRecordingState = () => {
    communicationAudioData = '';
    recordingChunks = [];
    updateRecordingButton(false);
    communicationPlayRecordingButton?.classList.add('d-none');
    setRecordingStatus('No recording yet. You can still save the button without a recording.');
};

const applyRecordingFromItem = (item = null) => {
    communicationAudioData = item?.audioData || '';
    const hasAudio = Boolean(communicationAudioData);
    communicationPlayRecordingButton?.classList.toggle('d-none', !hasAudio);
    setRecordingStatus(
        hasAudio
            ? 'Recording ready. Tap play to preview or record again.'
            : 'No recording yet. You can still save the button without a recording.',
        hasAudio ? 'success' : 'muted'
    );
    updateRecordingButton(false);
};

const stopRecordingStream = () => {
    if (recordingStream) {
        recordingStream.getTracks().forEach((track) => track.stop());
        recordingStream = null;
    }
};

const stopCommunicationAudio = () => {
    if (activeAudioElement) {
        activeAudioElement.pause();
        activeAudioElement.currentTime = 0;
        activeAudioElement = null;
    }
    isCommunicationAudioPlaying = false;
};

const playAudioData = (audioData) => {
    if (!audioData) {
        alert('Please record yourself saying this phrase first.');
        return;
    }
    if (isCommunicationAudioPlaying) {
        return;
    }
    stopCommunicationAudio();
    isCommunicationAudioPlaying = true;
    activeAudioElement = new Audio(audioData);
    activeAudioElement.onended = () => {
        activeAudioElement = null;
        isCommunicationAudioPlaying = false;
    };
    activeAudioElement.onerror = () => {
        isCommunicationAudioPlaying = false;
    };
    activeAudioElement.play().catch(() => {
        isCommunicationAudioPlaying = false;
        alert('Unable to play your recording. Please try re-recording.');
    });
};

const playFormRecording = () => playAudioData(communicationAudioData);

const startRecording = async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
        alert('Recording is not supported in this browser.');
        return;
    }
    if (typeof MediaRecorder === 'undefined') {
        alert('Recording is not available in this browser.');
        return;
    }

    try {
        communicationAudioData = '';
        communicationPlayRecordingButton?.classList.add('d-none');
        stopCommunicationAudio();
        recordingStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        recordingChunks = [];
        mediaRecorder = new MediaRecorder(recordingStream);
        mediaRecorder.ondataavailable = (event) => {
            if (event.data.size > 0) recordingChunks.push(event.data);
        };
        mediaRecorder.onstop = () => {
            const mimeType = recordingChunks[0]?.type || mediaRecorder.mimeType || 'audio/webm';
            const blob = new Blob(recordingChunks, { type: mimeType });
            const reader = new FileReader();
            reader.onloadend = () => {
                communicationAudioData = reader.result;
                communicationPlayRecordingButton?.classList.toggle('d-none', !communicationAudioData);
                setRecordingStatus(
                    'Recording ready. Tap play to preview or record again.',
                    communicationAudioData ? 'success' : 'muted'
                );
            };
            reader.readAsDataURL(blob);
            stopRecordingStream();
            updateRecordingButton(false);
        };
        mediaRecorder.start();
        updateRecordingButton(true);
        setRecordingStatus('Recording... tap stop when you are done.', 'success');
    } catch (error) {
        setRecordingStatus('Microphone permission is needed to record your voice.', 'error');
        stopRecordingStream();
    }
};

const stopRecording = () => {
    if (mediaRecorder && mediaRecorder.state === 'recording') {
        mediaRecorder.stop();
    } else {
        stopRecordingStream();
        updateRecordingButton(false);
    }
};

const toggleRecording = () => {
    if (mediaRecorder && mediaRecorder.state === 'recording') {
        stopRecording();
    } else {
        startRecording();
    }
};

const playCommunicationItemAudio = (item) => {
    if (!item.audioData) {
        alert('Please add your own recording for this card before playing it.');
        return;
    }
    playAudioData(item.audioData);
};

const focusCommunicationItem = (id) => {
    if (!communicationGrid || !id) return;
    const targetCard = communicationGrid.querySelector(`[data-communication-id="${id}"]`);
    if (!targetCard) return;
    targetCard.classList.add('communication-card--focused');
    targetCard.focus({ preventScroll: true });
    targetCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    window.setTimeout(() => {
        targetCard.classList.remove('communication-card--focused');
    }, 1800);
};

const renderCommunicationItems = () => {
    if (!communicationGrid) return;
    communicationGrid.innerHTML = '';

    communicationItems.forEach((item) => {
        const emoji = normalizeEmojiValue(item.emoji);
        const cleanTitle = stripLeadingEmoji(item.title || '', emoji);
        const cleanPhrase = stripLeadingEmoji(item.phrase || '', emoji);
        const displayTitle = cleanTitle || item.title || 'Communication card';
        const displayPhrase = cleanPhrase || item.phrase || '';
        const language = item.lang || 'en';
        const dir = language === 'ar' ? 'rtl' : 'ltr';
        const card = document.createElement('div');
        card.className = 'communication-card text-start';
        card.dataset.communicationId = item.id;
        card.style.background = `linear-gradient(145deg, ${hexToRgba(item.color, 0.18)}, var(--card-bg))`;
        card.setAttribute('role', 'button');
        card.setAttribute('tabindex', '0');
        card.setAttribute('aria-label', `${displayTitle}: ${displayPhrase}`);
        const recordingMessage = item.audioData
            ? '<span class="text-primary small fw-semibold">Tap card to play your recording</span>'
            : '<span class="text-warning small fw-semibold">Recording needed</span>';
        const fallbackEmoji = escapeHtml(emoji);
        const safeTitle = escapeHtml(displayTitle);
        const safePhrase = escapeHtml(displayPhrase || 'Tap to play your recording');
        const safeAlt = escapeHtml(item.title || displayTitle);

        card.innerHTML = `
            <div class="communication-image" style="border-color: ${hexToRgba(item.color, 0.4)};">
                ${item.imageData
                    ? `<img src="${item.imageData}" alt="${safeAlt}" loading="lazy">`
                    : `<div class="communication-placeholder" aria-hidden="true">
                        <span class="communication-emoji">${fallbackEmoji}</span>
                    </div>`}
            </div>
            <div class="fw-semibold" lang="${language}" dir="${dir}">${safeTitle}</div>
            <div class="text-muted small" lang="${language}" dir="${dir}">${safePhrase}</div>
            <div class="communication-meta">
                <div>${recordingMessage}</div>
                <div class="communication-actions">
                    <button class="btn btn-outline-danger btn-sm" data-action="delete-communication" aria-label="Delete communication card"><i class="bi bi-trash"></i></button>
                    <button class="btn btn-outline-primary btn-sm" data-action="edit-communication" aria-label="Edit communication card"><i class="bi bi-pencil"></i></button>
                </div>
            </div>
        `;

        communicationGrid.appendChild(card);
    });
};

const resetCommunicationPreview = () => {
    if (!communicationPreview) return;
    communicationPreview.textContent = 'No image selected';
    communicationPreview.dataset.imageData = '';
};

const setCommunicationFormMode = (item = null) => {
    const isEditing = Boolean(item);
    editingCommunicationId = item?.id || null;

    if (isEditing) {
        communicationTitleInput.value = item.title;
        if (communicationPhraseInput) {
            communicationPhraseInput.value = item.phrase || '';
        }
        if (communicationEmojiInput) {
            communicationEmojiInput.value = item.emoji || '';
        }
        if (communicationLanguageSelect) {
            communicationLanguageSelect.value = item.lang || 'en';
        }
        applyRecordingFromItem(item);
        if (item.imageData) {
            const safeTitle = escapeHtml(item.title || 'Communication image');
            communicationPreview.innerHTML = `<img src="${item.imageData}" alt="${safeTitle}">`;
            communicationPreview.dataset.imageData = item.imageData;
        } else {
            resetCommunicationPreview();
        }
    } else {
        communicationForm.reset();
        if (communicationEmojiInput) {
            communicationEmojiInput.value = '';
        }
        if (communicationPhraseInput) {
            communicationPhraseInput.value = '';
        }
        if (communicationLanguageSelect) {
            communicationLanguageSelect.value = 'en';
        }
        resetCommunicationPreview();
        resetRecordingState();
    }

    if (communicationSubmitButton) {
        communicationSubmitButton.innerHTML = isEditing
            ? '<i class="bi bi-save"></i> Update button'
            : '<i class="bi bi-plus-circle"></i> Save button';
    }

    communicationCancelButton?.classList.toggle('d-none', !isEditing);
};

const handleCommunicationFormSubmit = (e) => {
    e.preventDefault();
    const title = communicationTitleInput.value.trim();
    const audioData = communicationAudioData;
    const currentItem = editingCommunicationId
        ? communicationItems.find((item) => item.id === editingCommunicationId)
        : null;
    const phrase = communicationPhraseInput?.value.trim() || currentItem?.phrase || title;
    const language = communicationLanguageSelect?.value || currentItem?.lang || 'en';
    const emoji = normalizeEmojiValue(
        (communicationEmojiInput?.value || '').trim() || currentItem?.emoji || title.charAt(0),
        '🗣️'
    );

    if (!title) return;

    const createItem = (imageData = '') => {
        let focusId = editingCommunicationId;
        if (editingCommunicationId) {
            communicationItems = communicationItems.map((item) => (
                item.id === editingCommunicationId
                    ? {
                        ...item,
                        title,
                        phrase,
                        lang: language,
                        audioData,
                        imageData,
                        emoji
                    }
                    : item
            ));
        } else {
            const newItem = {
                id: `comm-${generateId()}`,
                title,
                phrase,
                audioData,
                lang: language,
                imageData,
                emoji,
                color: nextCommunicationColor(communicationItems.length),
                isCustom: true
            };
            communicationItems.push(newItem);
            focusId = newItem.id;
        }
        saveCommunicationItems();
        renderCommunicationItems();
        setCommunicationFormMode();
        focusCommunicationItem(focusId);
    };

    const file = communicationImageInput.files?.[0];
    if (file) {
        const reader = new FileReader();
        reader.onload = () => createItem(reader.result);
        reader.readAsDataURL(file);
    } else {
        createItem(communicationPreview?.dataset?.imageData || '');
    }
};

const handleCommunicationImageChange = () => {
    if (!communicationImageInput || !communicationPreview) return;
    const file = communicationImageInput.files?.[0];
    if (!file) {
        resetCommunicationPreview();
        return;
    }

    const reader = new FileReader();
    reader.onload = () => {
        communicationPreview.innerHTML = `<img src="${reader.result}" alt="Selected">`;
        communicationPreview.dataset.imageData = reader.result;
    };
    reader.readAsDataURL(file);
};

const deleteCommunicationItem = (id) => {
    const item = communicationItems.find(entry => entry.id === id);
    if (!item) return;
    if (!confirm(`Delete "${item.title || 'this card'}"?`)) return;
    stopCommunicationAudio();
    communicationItems = communicationItems.filter(entry => entry.id !== id);
    saveCommunicationItems();
    renderCommunicationItems();
};

const resetWorkspaceData = () => {
    stopCommunicationAudio();
    stopRecordingStream();
    communicationAudioData = '';
    recordingChunks = [];
    mediaRecorder = null;

    transactions = [];
    customCategories = [];
    todos = [];
    sharedParticipants = createDefaultSharedParticipants();
    sharedExpenses = [];
    communicationItems = DEFAULT_COMMUNICATION_ITEMS.map(item => ({ ...item }));

    saveTransactions();
    saveCustomCategories();
    saveTodos();
    saveSharedParticipants();
    saveSharedExpenses();
    saveCommunicationItems();

    activeCategoryFilter = '';
    if (categoryFilter) {
        categoryFilter.value = '';
    }
    transactionSearchQuery = '';
    if (transactionSearchInput) {
        transactionSearchInput.value = '';
    }
    todoSearchQuery = '';
    if (todoSearchInput) {
        todoSearchInput.value = '';
    }
    activeUrgencyFilter = '';
    if (urgencyFilter) {
        urgencyFilter.value = '';
    }
    descriptionInput.value = '';
    amountInput.value = '';
    if (urgencySelect) {
        urgencySelect.value = DEFAULT_URGENCY;
    }
    document.getElementById('incomeRadio').checked = true;
    setActiveCategory(null);

    renderTodos();
    renderCategoryOptions();
    renderCategoryPills();
    renderCategoryFilters();
    updateSharedExpenseControls();
    renderSharedParticipants();
    renderSharedExpenseHistory();
    normalizeCommunicationItems();
    renderCommunicationItems();
    setCommunicationFormMode();

    setActiveTab('finance');
    applyCommunicationFormState(true);
    safeStorage.set(ACTIVE_TAB_STORAGE_KEY, 'finance');
    safeStorage.set(COMMUNICATION_FORM_COLLAPSE_KEY, 'expanded');

    updateBalance();
    displayTransactions();
    setInputSectionVisibility(true);
};

const loadDemoData = () => {
    if (!confirm('Load demo data? This will replace your current workspace.')) return;
    const now = new Date();
    customCategories = [
        { value: 'pet-care', label: 'Pet care', type: 'expense', color: '#6f42c1' }
    ];
    CATEGORY_LOOKUP = buildCategoryLookup(getAllCategories());
    saveCustomCategories();

    transactions = [
        {
            id: generateId(),
            description: 'Paycheck',
            amount: 3200,
            type: 'income',
            category: 'salary',
            urgency: 'not-urgent',
            date: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 2).toISOString()
        },
        {
            id: generateId(),
            description: 'Groceries',
            amount: 145.32,
            type: 'expense',
            category: 'food',
            urgency: 'urgent',
            date: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1).toISOString()
        },
        {
            id: generateId(),
            description: 'Metro pass',
            amount: 60,
            type: 'expense',
            category: 'transport',
            urgency: 'later',
            date: now.toISOString()
        },
        {
            id: generateId(),
            description: 'Pet supplies',
            amount: 82.45,
            type: 'expense',
            category: 'pet-care',
            urgency: 'not-urgent',
            date: now.toISOString()
        },
        {
            id: generateId(),
            description: 'Freelance design',
            amount: 450,
            type: 'income',
            category: 'freelance',
            urgency: 'not-urgent',
            date: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 4).toISOString()
        }
    ].map((transaction, index) => normalizeTransaction(transaction, index));
    saveTransactions();

    todos = [
        {
            id: generateId(),
            text: 'Submit rent payment',
            priority: 'high',
            completed: false,
            createdAt: now.toISOString(),
            order: 10,
            dueDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2).toISOString().split('T')[0],
            subtasks: [
                { id: generateId(), text: 'Check balance', completed: true },
                { id: generateId(), text: 'Schedule transfer', completed: false }
            ]
        },
        {
            id: generateId(),
            text: 'Plan weekly meals',
            priority: 'normal',
            completed: false,
            createdAt: now.toISOString(),
            order: 20,
            dueDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 5).toISOString().split('T')[0],
            subtasks: []
        }
    ];
    saveTodos();

    sharedParticipants = [
        { id: generateId(), name: 'You' },
        { id: generateId(), name: 'Jordan' },
        { id: generateId(), name: 'Riley' }
    ];
    saveSharedParticipants();

    sharedExpenses = [
        {
            id: generateId(),
            description: 'Streaming subscription',
            amount: 18.99,
            payerId: sharedParticipants[0].id,
            participantIds: sharedParticipants.map((participant) => participant.id),
            date: now.toISOString()
        },
        {
            id: generateId(),
            description: 'Household supplies',
            amount: 54.2,
            payerId: sharedParticipants[1].id,
            participantIds: sharedParticipants.map((participant) => participant.id),
            date: now.toISOString()
        }
    ];
    saveSharedExpenses();

    communicationItems = [
        ...DEFAULT_COMMUNICATION_ITEMS.map(item => ({ ...item })),
        {
            id: `comm-${generateId()}`,
            title: 'Check in',
            phrase: 'Can we check in for a moment?',
            emoji: '✅',
            lang: 'en',
            color: '#20c997',
            isCustom: true,
            audioData: ''
        }
    ];
    saveCommunicationItems();

    activeCategoryFilter = '';
    activeUrgencyFilter = '';
    if (categoryFilter) categoryFilter.value = '';
    if (urgencyFilter) urgencyFilter.value = '';
    transactionSearchQuery = '';
    todoSearchQuery = '';
    if (transactionSearchInput) transactionSearchInput.value = '';
    if (todoSearchInput) todoSearchInput.value = '';

    renderCategoryOptions();
    renderCategoryPills();
    renderCategoryFilters();
    renderTodos();
    updateSharedExpenseControls();
    renderSharedParticipants();
    renderSharedExpenseHistory();
    normalizeCommunicationItems();
    renderCommunicationItems();
    updateBalance();
    displayTransactions();
    setActiveTab('finance');
    setCommunicationFormMode();
};

const handleImportFile = () => {
    const file = importDataInput?.files?.[0];
    if (!file) {
        alert('Please choose a file to import.');
        return;
    }
    const reader = new FileReader();
    reader.onload = () => {
        const content = reader.result;
        if (typeof content !== 'string') return;
        if (file.name.toLowerCase().endsWith('.json')) {
            try {
                const data = JSON.parse(content);
                importBackupData(data);
            } catch (error) {
                alert('Unable to read JSON file.');
            }
            if (importDataInput) importDataInput.value = '';
            return;
        }
        if (file.name.toLowerCase().endsWith('.csv')) {
            importTransactionsFromCsv(content);
            if (importDataInput) importDataInput.value = '';
            return;
        }
        alert('Unsupported file type. Please upload a CSV or JSON file.');
        if (importDataInput) importDataInput.value = '';
    };
    reader.readAsText(file);
};

// Event Listeners
addTransactionButton?.addEventListener('click', addTransaction);
saveTransactionButton?.addEventListener('click', saveEdit);
addCategoryButton?.addEventListener('click', addCustomCategory);
clearDataButton?.addEventListener('click', () => {
    if (confirm('Reset your workspace? This clears transactions, todos, shared balances, and communication cards.')) {
        resetWorkspaceData();
    }
});

exportDataButton?.addEventListener('click', exportToCSV);
exportBackupButton?.addEventListener('click', exportFullBackup);
importTransactionsButton?.addEventListener('click', handleImportFile);
loadDemoDataButton?.addEventListener('click', loadDemoData);
openHelpButton?.addEventListener('click', () => setActiveTab('help'));

toggleHistoryButton?.addEventListener('click', () => {
    if (!historySection) return;
    const isHidden = historySection.style.display === 'none';
    historySection.style.display = isHidden ? 'block' : 'none';
    if (transactions.length) {
        historySection.dataset.userToggled = 'true';
    }
    toggleHistoryButton.innerHTML = `<i class="bi bi-chevron-${isHidden ? 'up' : 'down'}"></i> ${isHidden ? 'Hide' : 'Show'}`;
    toggleHistoryButton.setAttribute('aria-expanded', isHidden ? 'true' : 'false');
});

const setInputSectionVisibility = (shouldShow) => {
    if (!inputSection || !toggleInputButton) return;
    inputSection.style.display = shouldShow ? 'block' : 'none';
    toggleInputButton.innerHTML = `<i class="bi bi-chevron-${shouldShow ? 'up' : 'down'}"></i> ${shouldShow ? 'Hide' : 'Show'}`;
    toggleInputButton.setAttribute('aria-expanded', shouldShow ? 'true' : 'false');
};

toggleInputButton?.addEventListener('click', () => {
    const isHidden = inputSection?.style.display === 'none';
    setInputSectionVisibility(isHidden);
});

historyList?.addEventListener('click', (e) => {
    const listItem = e.target.closest('.list-group-item');
    if (!listItem) return;
    
    if (e.target.closest('.delete-btn')) {
        if (confirm('Are you sure you want to delete this transaction?')) {
            deleteTransaction(parseInt(listItem.dataset.id));
        }
    } else if (e.target.closest('.edit-btn')) {
        const transaction = transactions.find(t => t.id === parseInt(listItem.dataset.id));
        if (transaction) startEdit(transaction);
    }
});

historyList?.addEventListener('change', (e) => {
    const select = e.target.closest('.urgency-select');
    if (!select) return;
    const listItem = select.closest('.list-group-item');
    if (!listItem) return;
    updateTransactionUrgency(parseInt(listItem.dataset.id), select.value);
});

categoryFilter?.addEventListener('change', filterTransactions);
urgencyFilter?.addEventListener('change', filterTransactions);
transactionSearchInput?.addEventListener('input', (event) => {
    transactionSearchQuery = event.target.value.trim().toLowerCase();
    displayTransactions();
    updateBalance();
});

categoryPillGroup?.addEventListener('click', (e) => {
    const pill = e.target.closest('.category-pill');
    if (!pill) return;
    setActiveCategory(pill.dataset.value);
});

categorySelect?.addEventListener('change', (e) => {
    setActiveCategory(e.target.value);
});

todoForm?.addEventListener('submit', (e) => {
    e.preventDefault();
    const text = todoInput.value.trim();
    if (!text) return;
    const dueDate = todoDueDateInput?.value || '';
    addTodo(text, todoPriority.value, dueDate);
    todoForm.reset();
    todoInput.focus();
});

todoSearchInput?.addEventListener('input', (event) => {
    todoSearchQuery = event.target.value.trim().toLowerCase();
    renderTodos();
});

todoList?.addEventListener('change', (e) => {
    const checkbox = e.target.closest('input[type="checkbox"]');
    if (!checkbox) return;
    const todoItem = checkbox.closest('li[data-id]');
    if (!todoItem) return;
    const todoId = parseInt(todoItem.dataset.id);
    
    if (checkbox.dataset.role === 'todo-toggle') {
        toggleTodo(todoId);
    } else if (checkbox.dataset.role === 'subtodo-toggle') {
        const subtaskId = parseInt(checkbox.dataset.subtaskId);
        toggleSubtask(todoId, subtaskId);
    }
});

todoList?.addEventListener('click', (e) => {
    const todoItem = e.target.closest('li[data-id]');
    if (!todoItem) return;
    const todoId = parseInt(todoItem.dataset.id);
    
    if (e.target.closest('[data-action="delete"]')) {
        deleteTodo(todoId);
        return;
    }
    
    if (e.target.closest('[data-action="add-subtask"]')) {
        const text = prompt('Sub-task description');
        if (text && text.trim()) {
            addSubtask(todoId, text.trim());
        }
        return;
    }
    
    const deleteSubtaskBtn = e.target.closest('[data-action="delete-subtask"]');
    if (deleteSubtaskBtn) {
        const subtaskId = parseInt(deleteSubtaskBtn.dataset.subtaskId);
        deleteSubtask(todoId, subtaskId);
    }
});

sharedParticipantForm?.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = sharedParticipantInput.value.trim();
    if (!name) return;
    addSharedParticipant(name);
    sharedParticipantForm.reset();
});

sharedParticipantList?.addEventListener('click', (e) => {
    const button = e.target.closest('[data-shared-action="delete-participant"]');
    if (!button) return;
    const item = button.closest('li[data-id]');
    if (!item) return;
    deleteSharedParticipant(parseInt(item.dataset.id));
});

sharedExpenseForm?.addEventListener('submit', (e) => {
    e.preventDefault();
    const description = sharedExpenseDescription.value.trim();
    const amount = parseFloat(sharedExpenseAmount.value);
    const payerId = parseInt(sharedExpensePayer.value);
    const selected = Array.from(sharedExpenseParticipants.querySelectorAll('input[type="checkbox"]:checked'))
        .map(input => parseInt(input.value));
    
    if (!description || isNaN(amount) || amount <= 0 || !payerId) {
        alert('Please complete the shared expense form');
        return;
    }
    
    addSharedExpense(description, amount, payerId, selected);
    sharedExpenseForm.reset();
    updateSharedExpenseControls();
});

sharedExpenseHistory?.addEventListener('click', (e) => {
    const item = e.target.closest('li[data-id]');
    if (!item) return;
    if (!e.target.closest('[data-shared-action="delete-expense"]')) return;
    const id = parseInt(item.dataset.id);
    sharedExpenses = sharedExpenses.filter(expense => expense.id !== id);
    saveSharedExpenses();
    renderSharedExpenseHistory();
    renderSharedParticipants();
});

resetSharedBalancesButton?.addEventListener('click', () => {
    if (confirm('Clear all shared expenses?')) {
        resetSharedExpenses();
    }
});
shareSplitSummaryButton?.addEventListener('click', () => {
    copySplitSummary();
});

communicationForm?.addEventListener('submit', handleCommunicationFormSubmit);
communicationImageInput?.addEventListener('change', handleCommunicationImageChange);
communicationRecordButton?.addEventListener('click', toggleRecording);
communicationPlayRecordingButton?.addEventListener('click', playFormRecording);
communicationGrid?.addEventListener('click', (e) => {
    const card = e.target.closest('[data-communication-id]');
    if (!card) return;
    const id = card.dataset.communicationId;
    const item = communicationItems.find(entry => entry.id === id);
    if (!item) return;

    if (e.target.closest('[data-action="delete-communication"]')) {
        deleteCommunicationItem(id);
        return;
    }

    if (e.target.closest('[data-action="edit-communication"]')) {
        setCommunicationFormMode(item);
        communicationTitleInput.focus();
        return;
    }

    playCommunicationItemAudio(item);
});
communicationGrid?.addEventListener('keydown', (e) => {
    const card = e.target.closest('[data-communication-id]');
    if (!card) return;
    if (e.target.closest('button')) return;
    if (e.key !== 'Enter' && e.key !== ' ') return;
    e.preventDefault();
    const id = card.dataset.communicationId;
    const item = communicationItems.find(entry => entry.id === id);
    if (item) {
        playCommunicationItemAudio(item);
    }
});
communicationStopButton?.addEventListener('click', () => {
    stopCommunicationAudio();
    stopRecording();
});
communicationCancelButton?.addEventListener('click', () => setCommunicationFormMode());
communicationFormBody?.addEventListener('shown.bs.collapse', () => applyCommunicationFormState(true));
communicationFormBody?.addEventListener('hidden.bs.collapse', () => applyCommunicationFormState(false));
requestNotificationPermissionButton?.addEventListener('click', requestNotificationPermission);
copyPushSubscriptionButton?.addEventListener('click', copyPushSubscription);
clearPushSubscriptionButton?.addEventListener('click', clearPushSubscription);
reminderRecurrenceSelect?.addEventListener('change', updateRecurrenceFields);
reminderTimeInput?.addEventListener('change', () => {
    setMonthlyDayFromTime();
    setWeekdaySelectionFromTime();
});
reminderForm?.addEventListener('submit', (event) => {
    event.preventDefault();
    addReminder();
});
reminderList?.addEventListener('click', (event) => {
    const button = event.target.closest('[data-action="delete-reminder"]');
    if (!button) return;
    const listItem = button.closest('li[data-id]');
    if (!listItem) return;
    const reminderId = parseInt(listItem.dataset.id);
    reminders = reminders.filter(reminder => reminder.id !== reminderId);
    saveReminders();
    renderReminders();
    clearScheduledNotification(reminderId);
});
shortcutForm?.addEventListener('submit', (event) => {
    event.preventDefault();
    addShortcut(
        shortcutTitleInput?.value || '',
        shortcutDescriptionInput?.value || '',
        shortcutRoutineInput?.value || '',
        shortcutLinkInput?.value || ''
    );
    shortcutForm.reset();
});
shortcutList?.addEventListener('click', (event) => {
    const deleteButton = event.target.closest('[data-action="delete-shortcut"]');
    if (!deleteButton) return;
    const card = deleteButton.closest('[data-shortcut-id]');
    if (!card) return;
    deleteShortcut(card.dataset.shortcutId);
});

themeToggle?.addEventListener('click', (event) => {
    const button = event.target.closest('[data-theme-mode]');
    if (!button) return;
    setThemeMode(button.dataset.themeMode);
});

accentOptionsContainer?.addEventListener('click', (e) => {
    const swatch = e.target.closest('.accent-swatch');
    if (!swatch) return;
    setAccent(swatch.dataset.accent);
});

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    renderCategoryOptions();
    renderCategoryPills();
    renderCategoryFilters();
    initializeThemeControls();
    transactionSearchQuery = transactionSearchInput?.value.trim().toLowerCase() || '';
    todoSearchQuery = todoSearchInput?.value.trim().toLowerCase() || '';
    setupTabs();
    const savedTab = safeStorage.get(ACTIVE_TAB_STORAGE_KEY);
    const validTab = savedTab && Array.from(tabButtons).some((button) => button.dataset.tabTarget === savedTab);
    setActiveTab(validTab ? savedTab : 'finance');
    renderTodos();
    renderShortcuts();
    renderSharedParticipants();
    updateSharedExpenseControls();
    renderSharedExpenseHistory();
    normalizeCommunicationItems();
    renderCommunicationItems();
    renderReminders();
    updateNotificationStatus();
    updatePushStatus();
    updateReminderTimeMin();
    buildMonthlyDayOptions();
    updateRecurrenceFields();
    setMonthlyDayFromTime();
    checkDueReminders();
    reminderCheckInterval = setInterval(checkDueReminders, 30000);
    registerServiceWorker().then(() => schedulePendingReminderTriggers());

    transactions = loadTransactions();
    updateBalance();
    displayTransactions();
    setCommunicationFormMode();
    setInputSectionVisibility(true);
    const savedCommunicationFormState = safeStorage.get(COMMUNICATION_FORM_COLLAPSE_KEY);
    const shouldExpand = savedCommunicationFormState !== 'collapsed';
    applyCommunicationFormState(shouldExpand);
});
