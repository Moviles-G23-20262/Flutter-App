import { useState, type ReactNode } from "react";

// ─── Types ─────────────────────────────────────────────────────────────────

type Screen = "login" | "home" | "search" | "product" | "messages" | "profile" | "sellerHub" | "newListing" | "cart" | "checkout" | "confirmation";
type Theme  = "dark" | "light";
type ListingCondition = "NEW" | "LIKE_NEW" | "GOOD" | "FAIR";

interface Product {
  id: number;
  name: string;
  price: number;
  condition: "New" | "Like New" | "Good" | "Fair";
  category: string;
  seller: string;
  sellerAvatar: string;
  image: string;
  description: string;
  rating: number;
  reviews: number;
  course?: string;
}

interface CartItem {
  product: Product;
  qty: number;
}

// ─── Data ──────────────────────────────────────────────────────────────────

const PRODUCTS: Product[] = [
  {
    id: 1,
    name: "Casio fx-991EX Scientific Calculator",
    price: 18.00,
    condition: "Like New",
    category: "Calculators",
    seller: "Maria Santos",
    sellerAvatar: "MS",
    image: "https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=400&h=300&fit=crop&auto=format",
    description: "Barely used during one semester. No scratches, all buttons work perfectly. Comes with original case and manual. Great for engineering and math courses.",
    rating: 4.9,
    reviews: 12,
    course: "MATH 201"
  },
  {
    id: 2,
    name: "Organic Chemistry Textbook 12th Ed.",
    price: 24.50,
    condition: "Good",
    category: "Textbooks",
    seller: "Jake Reyes",
    sellerAvatar: "JR",
    image: "https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400&h=300&fit=crop&auto=format",
    description: "Used for CHEM 301. Some highlighting in chapters 3-5 but otherwise clean. All pages intact.",
    rating: 4.7,
    reviews: 8,
    course: "CHEM 301"
  },
  {
    id: 3,
    name: "Lab Coat Size M — Pristine",
    price: 12.00,
    condition: "Like New",
    category: "Lab Supplies",
    seller: "Ana Cruz",
    sellerAvatar: "AC",
    image: "https://images.unsplash.com/photo-1584820927498-cfe5211fd8bf?w=400&h=300&fit=crop&auto=format",
    description: "Standard white lab coat, size medium. Worn only a few times in BIO lab. Washed and ready.",
    rating: 4.8,
    reviews: 5,
    course: "BIO 201"
  },
  {
    id: 4,
    name: "Data Structures & Algorithms Book",
    price: 20.00,
    condition: "Good",
    category: "Textbooks",
    seller: "Leo Tan",
    sellerAvatar: "LT",
    image: "https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=400&h=300&fit=crop&auto=format",
    description: "Used for CS 301. Notes written in pencil (mostly erasable). Solid reference for algorithms interviews too.",
    rating: 4.6,
    reviews: 21,
    course: "CS 301"
  },
  {
    id: 5,
    name: "TI-84 Plus Graphing Calculator",
    price: 35.00,
    condition: "Good",
    category: "Calculators",
    seller: "Sofia Lim",
    sellerAvatar: "SL",
    image: "https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=400&h=300&fit=crop&auto=format",
    description: "TI-84 Plus in good working condition. Battery door has minor crack but functions perfectly. Ideal for stats and calculus.",
    rating: 4.5,
    reviews: 17,
    course: "STAT 201"
  },
  {
    id: 6,
    name: "Engineering Drawing Set",
    price: 9.00,
    condition: "Fair",
    category: "Supplies",
    seller: "Karl Mendoza",
    sellerAvatar: "KM",
    image: "https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=400&h=300&fit=crop&auto=format",
    description: "Complete set with compass, protractor, and drafting pencils. Used for one semester of engineering drawing.",
    rating: 4.2,
    reviews: 6,
    course: "ENG 101"
  },
];

const CATEGORIES = ["All", "Calculators", "Textbooks", "Lab Supplies", "Supplies", "Notes", "Electronics"];

const SELLERS = [
  { name: "Maria Santos", avatar: "MS", items: 8,  rating: 4.9 },
  { name: "Jake Reyes",   avatar: "JR", items: 5,  rating: 4.7 },
  { name: "Ana Cruz",     avatar: "AC", items: 12, rating: 4.8 },
  { name: "Leo Tan",      avatar: "LT", items: 3,  rating: 4.6 },
];

const USER_PROFILE = {
  name: "Maria Santos",
  avatar: "MS",
  email: "maria.santos@university.edu",
  faculty: "Faculty of Engineering",
  major: "BS Computer Science",
  semester: "6th Semester",
  campus: "UP Diliman",
  rating: 4.9,
  swaps: 18,
};

const PURCHASE_HISTORY = [
  { product: PRODUCTS[1], seller: "Jake Reyes", date: "Sep 12", status: "Meetup complete" },
  { product: PRODUCTS[3], seller: "Leo Tan", date: "Aug 28", status: "Picked up" },
  { product: PRODUCTS[5], seller: "Karl Mendoza", date: "Aug 11", status: "Paid in cash" },
];

const CONVERSATIONS = [
  {
    name: "Jake Reyes",
    avatar: "JR",
    item: "Organic Chemistry Textbook",
    last: "Library steps at 3 PM works for me.",
    time: "2m ago",
    unread: 2,
    online: true,
    place: "Main Library steps",
    meetupTime: "Today, 3:00 PM",
    messages: [
      { from: "them", text: "Hey, is the Organic Chemistry textbook still available?", time: "2:21 PM" },
      { from: "me", text: "Yes, it is. It has some highlighting in chapters 3-5, but all pages are intact.", time: "2:23 PM" },
      { from: "them", text: "That works. Could we meet near the library?", time: "2:24 PM" },
      { from: "me", text: "Sure. Library steps at 3 PM works for me.", time: "2:25 PM" },
    ],
  },
  {
    name: "Sofia Lim",
    avatar: "SL",
    item: "TI-84 Plus Calculator",
    last: "Could you do P32 if I pick it up today?",
    time: "18m ago",
    unread: 0,
    online: true,
    place: "Engineering lobby",
    meetupTime: "Today, 5:15 PM",
    messages: [
      { from: "them", text: "Could you do P32 if I pick it up today?", time: "1:58 PM" },
      { from: "me", text: "I can meet you at the Engineering lobby after class.", time: "2:02 PM" },
      { from: "them", text: "Perfect, I can be there around 5:15.", time: "2:04 PM" },
    ],
  },
  {
    name: "Ana Cruz",
    avatar: "AC",
    item: "Lab Coat Size M",
    last: "I can bring it after BIO lab.",
    time: "1h ago",
    unread: 0,
    online: false,
    place: "Science building entrance",
    meetupTime: "Tomorrow, 10:30 AM",
    messages: [
      { from: "me", text: "Hi Ana, is the lab coat still clean and ready?", time: "12:31 PM" },
      { from: "them", text: "Yes, washed and ready. I can bring it after BIO lab.", time: "12:39 PM" },
      { from: "me", text: "Great. Science building entrance tomorrow?", time: "12:42 PM" },
    ],
  },
  {
    name: "Leo Tan",
    avatar: "LT",
    item: "Data Structures Book",
    last: "Still available, pages are all intact.",
    time: "3h ago",
    unread: 1,
    online: false,
    place: "Computer Science lounge",
    meetupTime: "Friday, 1:00 PM",
    messages: [
      { from: "me", text: "Is the Data Structures book still available?", time: "10:10 AM" },
      { from: "them", text: "Still available, pages are all intact.", time: "10:12 AM" },
      { from: "them", text: "There are pencil notes in the graph chapters.", time: "10:13 AM" },
    ],
  },
];

// ─── Icons ──────────────────────────────────────────────────────────────────

const Icon = {
  CampusSwap: ({ size = 24 }: { size?: number }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 9 C4 5 20 5 20 9" /><polyline points="17 6 20 9 17 12" />
      <path d="M20 15 C20 19 4 19 4 15" /><polyline points="7 12 4 15 7 18" />
    </svg>
  ),
  Home: () => (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" /><polyline points="9 22 9 12 15 12 15 22" />
    </svg>
  ),
  Search: () => (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  ),
  Cart: () => (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="9" cy="21" r="1" /><circle cx="20" cy="21" r="1" />
      <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6" />
    </svg>
  ),
  User: () => (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" />
    </svg>
  ),
  Heart: ({ filled = false }: { filled?: boolean }) => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill={filled ? "var(--accent)" : "none"} stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
    </svg>
  ),
  Star: ({ filled = true }: { filled?: boolean }) => (
    <svg width="13" height="13" viewBox="0 0 24 24" fill={filled ? "var(--accent-hi)" : "none"} stroke="var(--accent-hi)" strokeWidth="2">
      <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
    </svg>
  ),
  Plus: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
      <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  ),
  Minus: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
      <line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  ),
  Back: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <line x1="19" y1="12" x2="5" y2="12" /><polyline points="12 19 5 12 12 5" />
    </svg>
  ),
  Check: ({ size = 36, color = "currentColor" }: { size?: number; color?: string }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  ),
  Bell: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  ),
  Filter: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3" />
    </svg>
  ),
  Location: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" /><circle cx="12" cy="10" r="3" />
    </svg>
  ),
  Eye: () => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" />
    </svg>
  ),
  Message: ({ size = 15 }: { size?: number }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
    </svg>
  ),
  Image: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <circle cx="8.5" cy="8.5" r="1.5" />
      <polyline points="21 15 16 10 5 21" />
    </svg>
  ),
  Camera: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
      <circle cx="12" cy="13" r="4" />
    </svg>
  ),
  Flame: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z" />
    </svg>
  ),
  BookOpen: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" /><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
    </svg>
  ),
  Store: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 9l1-5h16l1 5" /><path d="M3 9a2 2 0 0 0 2 2 2 2 0 0 0 2-2 2 2 0 0 0 2 2 2 2 0 0 0 2-2 2 2 0 0 0 2 2 2 2 0 0 0 2-2" />
      <path d="M5 21V11" /><path d="M19 21V11" /><rect x="9" y="14" width="6" height="7" rx="1" />
    </svg>
  ),
  Wallet: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 12V7H5a2 2 0 0 1 0-4h14v4" /><path d="M3 5v14a2 2 0 0 0 2 2h16v-5" /><path d="M18 12a2 2 0 0 0 0 4h4v-4z" />
    </svg>
  ),
  Package: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="16.5" y1="9.4" x2="7.5" y2="4.21" />
      <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
      <polyline points="3.27 6.96 12 12.01 20.73 6.96" /><line x1="12" y1="22.08" x2="12" y2="12" />
    </svg>
  ),
  Tag: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" /><line x1="7" y1="7" x2="7.01" y2="7" />
    </svg>
  ),
  Sparkle: () => (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 2l2.4 7.4H22l-6.2 4.5 2.4 7.4L12 17l-6.2 4.3 2.4-7.4L2 9.4h7.6z" />
    </svg>
  ),
  Clock: () => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
    </svg>
  ),
  Inbox: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="22 12 16 12 14 15 10 15 8 12 2 12" />
      <path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z" />
    </svg>
  ),
  TrendingUp: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="23 6 13.5 15.5 8.5 10.5 1 18" /><polyline points="17 6 23 6 23 12" />
    </svg>
  ),
  ShoppingBag: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" /><line x1="3" y1="6" x2="21" y2="6" /><path d="M16 10a4 4 0 0 1-8 0" />
    </svg>
  ),
  Send: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="22" y1="2" x2="11" y2="13" /><polygon points="22 2 15 22 11 13 2 9 22 2" />
    </svg>
  ),
  ArrowRight: () => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />
    </svg>
  ),
  CheckCircle: () => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" /><polyline points="22 4 12 14.01 9 11.01" />
    </svg>
  ),
  MapPin: () => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" /><circle cx="12" cy="10" r="3" />
    </svg>
  ),
  Pencil: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" /><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
    </svg>
  ),
  Close: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
      <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
    </svg>
  ),
  Sell: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  ),
  Sun: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="5" />
      <line x1="12" y1="1" x2="12" y2="3" /><line x1="12" y1="21" x2="12" y2="23" />
      <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" /><line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
      <line x1="1" y1="12" x2="3" y2="12" /><line x1="21" y1="12" x2="23" y2="12" />
      <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" /><line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
    </svg>
  ),
  Moon: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
    </svg>
  ),
};

// ─── Shared inline style helpers ─────────────────────────────────────────────

const S = {
  iconBtn: {
    background: "var(--bg-elevated)",
    border: "1px solid var(--bd-subtle)",
    borderRadius: 10,
    width: 36,
    height: 36,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    cursor: "pointer",
    color: "var(--tx-2)",
    flexShrink: 0,
  } as React.CSSProperties,
  card: {
    background: "var(--bg-surface)",
    border: "1px solid var(--bd)",
    borderRadius: 16,
    boxShadow: "0 2px 10px var(--shadow-card)",
  } as React.CSSProperties,
  header: {
    background: "var(--bg-surface)",
    borderBottom: "1px solid var(--bd)",
    padding: "14px 18px 12px",
    flexShrink: 0,
  } as React.CSSProperties,
};

// ─── Bottom Nav ─────────────────────────────────────────────────────────────

function BottomNav({ screen, setScreen }: {
  screen: Screen; setScreen: (s: Screen) => void;
}) {
  return (
    <div style={{ background: "var(--bg-surface)", borderTop: "1px solid var(--bd)", padding: "10px 0 10px", flexShrink: 0 }}
      className="flex items-center justify-around">
      <button className={`nav-tab ${screen === "home" ? "active" : ""}`} onClick={() => setScreen("home")}>
        <Icon.Home /><span>Home</span>
      </button>
      <button className={`nav-tab ${screen === "search" ? "active" : ""}`} onClick={() => setScreen("search")}>
        <Icon.Search /><span>Search</span>
      </button>
      <button onClick={() => setScreen("newListing")}
        style={{ background: "var(--accent)", border: "1px solid var(--accent-lo)", borderRadius: 12, padding: "10px 18px", boxShadow: "0 2px 10px var(--shadow-accent)", color: "var(--accent-tx)", display: "flex", alignItems: "center", gap: 6, cursor: "pointer", marginTop: -14 }}>
        <Icon.Sell /><span style={{ fontFamily: "var(--font-body)", fontWeight: 600, fontSize: "0.88rem" }}>Sell</span>
      </button>
      <button className={`nav-tab ${screen === "messages" ? "active" : ""}`} onClick={() => setScreen("messages")}>
        <Icon.Message size={22} /><span>Messages</span>
      </button>
      <button className={`nav-tab ${screen === "profile" || screen === "sellerHub" ? "active" : ""}`} onClick={() => setScreen("profile")}>
        <Icon.User /><span>Profile</span>
      </button>
    </div>
  );
}

// ─── Login Screen ────────────────────────────────────────────────────────────

function LoginScreen({ onLogin }: { onLogin: () => void }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError]       = useState("");
  const [loading, setLoading]   = useState(false);

  const handleLogin = () => {
    if (username === "uwu" && password === "uwu123") {
      setLoading(true);
      setTimeout(() => onLogin(), 800);
    } else {
      setError("Wrong credentials. Check the note below.");
    }
  };

  return (
    <div className="flex flex-col" style={{ flex: 1, overflowY: "auto", background: "var(--bg)" }}>
      <div className="flex flex-col items-center pt-16 pb-6 px-6 flex-1">
        <div style={{ background: "var(--accent)", borderRadius: 20, width: 72, height: 72, display: "flex", alignItems: "center", justifyContent: "center", border: "1px solid var(--accent-lo)", boxShadow: "0 4px 20px var(--shadow-accent)", marginBottom: 16, color: "var(--accent-tx)" }}>
          <Icon.CampusSwap size={36} />
        </div>
        <h1 className="font-chewy" style={{ fontSize: "var(--type-lg)", color: "var(--tx)", fontWeight: 700, letterSpacing: "-0.02em", marginBottom: 6 }}>
          Campus Swap
        </h1>
        <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", marginBottom: 36, textAlign: "center", lineHeight: 1.5 }}>
          Buy. Sell. Swap. All on campus.
        </p>

        <div style={{ ...S.card, padding: "28px 24px", width: "100%" }}>
          <h2 className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600, marginBottom: 20 }}>Welcome back</h2>
          <div className="flex flex-col gap-4">
            <div>
              <label className="font-delius" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", display: "block", marginBottom: 6 }}>Username</label>
              <input className="input-field w-full" value={username} onChange={e => { setUsername(e.target.value); setError(""); }}
                placeholder="Enter your username" onKeyDown={e => e.key === "Enter" && handleLogin()} />
            </div>
            <div>
              <label className="font-delius" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", display: "block", marginBottom: 6 }}>Password</label>
              <input className="input-field w-full" type="password" value={password} onChange={e => { setPassword(e.target.value); setError(""); }}
                placeholder="Enter your password" onKeyDown={e => e.key === "Enter" && handleLogin()} />
            </div>
            {error && (
              <p className="font-opensans" style={{ color: "var(--error-color)", fontSize: "var(--type-xs)", background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 8, padding: "8px 12px" }}>{error}</p>
            )}
            <button className="btn-primary w-full mt-2" style={{ padding: "13px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }} onClick={handleLogin} disabled={loading}>
              <Icon.Send />{loading ? "Logging in..." : "Log In"}
            </button>
            <p className="font-opensans" style={{ textAlign: "center", color: "var(--tx-muted)", fontSize: "var(--type-xs)" }}>
              No account? <span style={{ color: "var(--accent-hi)", fontWeight: 600, cursor: "pointer" }}>Sign up free</span>
            </p>
          </div>
        </div>
      </div>

      <div className="px-6 pb-10">
        <div className="sticky-note animate-wiggle" style={{ animationDuration: "2.5s" }}>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
            <div style={{ color: "var(--tx-muted)", flexShrink: 0, marginTop: 2 }}><Icon.Pencil /></div>
            <div>
              <p className="font-delius" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700, marginBottom: 4 }}>Demo Credentials</p>
              <p className="font-mono" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", lineHeight: 1.8 }}>
                username: uwu<br />password: uwu123
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Home Screen ─────────────────────────────────────────────────────────────

function HomeScreen({ setScreen, setViewProduct, theme, toggleTheme }: {
  setScreen: (s: Screen) => void; setViewProduct: (p: Product) => void;
  theme: Theme; toggleTheme: () => void;
}) {
  const [activeCategory, setActiveCategory] = useState("All");
  const [favorites, setFavorites] = useState<number[]>([]);

  const toggleFav = (id: number) =>
    setFavorites(prev => prev.includes(id) ? prev.filter(f => f !== id) : [...prev, id]);

  const filtered = activeCategory === "All" ? PRODUCTS : PRODUCTS.filter(p => p.category === activeCategory);

  return (
    <>
      <div style={S.header}>
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <div style={{ background: "var(--accent)", borderRadius: 10, width: 34, height: 34, display: "flex", alignItems: "center", justifyContent: "center", border: "1px solid var(--accent-lo)", color: "var(--accent-tx)" }}>
              <Icon.CampusSwap size={18} />
            </div>
            <span className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600, letterSpacing: "-0.01em" }}>Campus Swap</span>
          </div>
          <div className="flex items-center gap-2">
            <button style={S.iconBtn} onClick={toggleTheme} title="Toggle theme">
              {theme === "dark" ? <Icon.Sun /> : <Icon.Moon />}
            </button>
            <button style={S.iconBtn}><Icon.Bell /></button>
            <button style={S.iconBtn}><Icon.Heart /></button>
          </div>
        </div>
        <div style={{ position: "relative" }}>
          <div style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)", color: "var(--tx-muted)" }}><Icon.Search /></div>
          <input className="input-field w-full" style={{ paddingLeft: 40 }} placeholder="Search course materials..." onClick={() => setScreen("search")} readOnly />
        </div>
      </div>

      <div style={{ flex: 1, overflowY: "auto" }}>
        <div className="px-4 pt-4">
          <div className="hero-card p-5">
            <div style={{ display: "inline-flex", alignItems: "center", gap: 5, background: "rgba(255,255,255,0.12)", borderRadius: 999, padding: "3px 12px", marginBottom: 10, border: "1px solid rgba(255,255,255,0.2)" }}>
              <Icon.Sparkle />
              <span className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "rgba(255,255,255,0.9)", fontWeight: 500 }}>Weekly Deal</span>
            </div>
            <h2 className="font-chewy" style={{ fontSize: "var(--type-md)", marginBottom: 6, color: "#f9f9f9", fontWeight: 600, lineHeight: 1.2 }}>
              Save big on course materials
            </h2>
            <p className="font-opensans" style={{ fontSize: "var(--type-xs)", opacity: 0.8, marginBottom: 16, color: "#f9f9f9", lineHeight: 1.5 }}>
              Buy from fellow students and save up to 70% on textbooks, calculators and more.
            </p>
            <button onClick={() => setScreen("search")}
              style={{ background: "rgba(255,255,255,0.15)", border: "1px solid rgba(255,255,255,0.3)", color: "#f9f9f9", borderRadius: 8, padding: "8px 16px", cursor: "pointer", fontFamily: "var(--font-body)", fontWeight: 600, fontSize: "var(--type-xs)", display: "inline-flex", alignItems: "center", gap: 6 }}>
              Browse Materials <Icon.ArrowRight />
            </button>
          </div>
        </div>

        <div className="px-4 pt-5">
          <h3 className="section-title mb-3">Categories</h3>
          <div className="flex gap-2 overflow-x-auto pb-2" style={{ scrollbarWidth: "none" }}>
            {CATEGORIES.map(cat => (
              <button key={cat} className={`pill ${activeCategory === cat ? "active" : ""}`} onClick={() => setActiveCategory(cat)}>{cat}</button>
            ))}
          </div>
        </div>

        <div className="px-4 pt-5">
          <div className="flex items-center justify-between mb-3">
            <h3 className="section-title flex items-center gap-2"><span style={{ color: "var(--accent-hi)" }}><Icon.Flame /></span>Current Offers</h3>
            <button className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", background: "none", border: "none", cursor: "pointer", display: "flex", alignItems: "center", gap: 3 }} onClick={() => setScreen("search")}>
              See all <Icon.ArrowRight />
            </button>
          </div>
          <div className="flex gap-3 overflow-x-auto pb-2" style={{ scrollbarWidth: "none" }}>
            {filtered.slice(0, 4).map(p => (
              <div key={p.id} className="product-card" style={{ minWidth: 155, flexShrink: 0 }} onClick={() => { setViewProduct(p); setScreen("product"); }}>
                <div style={{ height: 110, overflow: "hidden", background: "var(--bg-elevated)" }}>
                  <img src={p.image} alt={p.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                </div>
                <div style={{ padding: "10px 10px 12px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 6 }}>
                    <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600, lineHeight: 1.3, flex: 1, marginRight: 4 }}>{p.name}</p>
                    <button onClick={e => { e.stopPropagation(); toggleFav(p.id); }} style={{ background: "none", border: "none", cursor: "pointer", padding: 0, flexShrink: 0 }}>
                      <Icon.Heart filled={favorites.includes(p.id)} />
                    </button>
                  </div>
                  <div className="badge" style={{ marginBottom: 6 }}>{p.condition}</div>
                  <p className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>P{p.price.toFixed(2)}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="px-4 pt-5">
          <div className="flex items-center justify-between mb-3">
            <h3 className="section-title flex items-center gap-2"><span style={{ color: "var(--accent-hi)" }}><Icon.BookOpen /></span>Recommended</h3>
            <button className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", background: "none", border: "none", cursor: "pointer", display: "flex", alignItems: "center", gap: 3 }} onClick={() => setScreen("search")}>
              See all <Icon.ArrowRight />
            </button>
          </div>
          <div className="flex flex-col gap-3">
            {PRODUCTS.slice(1, 4).map(p => (
              <div key={p.id} style={{ ...S.card, padding: "12px", display: "flex", gap: 12, alignItems: "center", cursor: "pointer" }}
                onClick={() => { setViewProduct(p); setScreen("product"); }}>
                <div style={{ width: 68, height: 68, borderRadius: 10, overflow: "hidden", flexShrink: 0, background: "var(--bg-elevated)" }}>
                  <img src={p.image} alt={p.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                </div>
                <div style={{ flex: 1 }}>
                  <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600, marginBottom: 5, lineHeight: 1.3 }}>{p.name}</p>
                  <div style={{ display: "flex", gap: 5, marginBottom: 6 }}>
                    <span className="badge">{p.condition}</span>
                    {p.course && <span className="badge purple">{p.course}</span>}
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>P{p.price.toFixed(2)}</span>
                    <button className="btn-primary" style={{ padding: "5px 12px", fontSize: "var(--type-xs)", display: "flex", alignItems: "center", gap: 5 }}
                      onClick={e => { e.stopPropagation(); setScreen("messages"); }}>
                      <Icon.Message /> Message
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="px-4 pt-5 pb-6">
          <h3 className="section-title mb-3 flex items-center gap-2"><span style={{ color: "var(--accent-hi)" }}><Icon.Star /></span>Featured Sellers</h3>
          <div className="flex gap-3 overflow-x-auto pb-2" style={{ scrollbarWidth: "none" }}>
            {SELLERS.map(s => (
              <div key={s.name} style={{ ...S.card, padding: "14px 16px", minWidth: 126, flexShrink: 0, textAlign: "center", cursor: "pointer" }}>
                <div style={{ width: 44, height: 44, background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 8px" }}>
                  <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "0.82rem", fontWeight: 700 }}>{s.avatar}</span>
                </div>
                <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600, marginBottom: 2 }}>{s.name}</p>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 3, marginBottom: 2 }}>
                  <Icon.Star filled />
                  <span className="font-mono" style={{ fontSize: "var(--type-2xs)", color: "var(--tx-muted)" }}>{s.rating}</span>
                </div>
                <p className="font-opensans" style={{ fontSize: "var(--type-2xs)", color: "var(--tx-muted)" }}>{s.items} items</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}

// ─── Search Screen ────────────────────────────────────────────────────────────

function SearchScreen({ setScreen, setViewProduct }: { setScreen: (s: Screen) => void; setViewProduct: (p: Product) => void }) {
  const [query, setQuery]             = useState("");
  const [category, setCategory]       = useState("All");
  const [condition, setCondition]     = useState("All");
  const [sortBy, setSortBy]           = useState("default");
  const [maxPrice, setMaxPrice]       = useState(100);
  const [showFilters, setShowFilters] = useState(false);

  let results = PRODUCTS.filter(p => {
    if (category !== "All" && p.category !== category) return false;
    if (condition !== "All" && p.condition !== condition) return false;
    if (p.price > maxPrice) return false;
    if (query && !p.name.toLowerCase().includes(query.toLowerCase()) && !p.category.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  });
  if (sortBy === "price-asc")  results = [...results].sort((a, b) => a.price - b.price);
  if (sortBy === "price-desc") results = [...results].sort((a, b) => b.price - a.price);
  if (sortBy === "rating")     results = [...results].sort((a, b) => b.rating - a.rating);

  return (
    <>
      <div style={S.header}>
        <div className="flex items-center gap-3 mb-3">
          <button style={S.iconBtn} onClick={() => setScreen("home")}><Icon.Back /></button>
          <div style={{ position: "relative", flex: 1 }}>
            <div style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)", color: "var(--tx-muted)" }}><Icon.Search /></div>
            <input className="input-field w-full" style={{ paddingLeft: 40 }} placeholder="Search course materials..."
              value={query} onChange={e => setQuery(e.target.value)} autoFocus />
          </div>
          <button style={{ ...S.iconBtn, background: showFilters ? "var(--accent)" : "var(--bg-elevated)", color: showFilters ? "var(--accent-tx)" : "var(--tx-2)", borderColor: showFilters ? "var(--accent-lo)" : "var(--bd-subtle)" }}
            onClick={() => setShowFilters(!showFilters)}>
            <Icon.Filter />
          </button>
        </div>
        {showFilters && (
          <div style={{ background: "var(--bg-elevated)", borderRadius: 12, padding: "12px", border: "1px solid var(--bd-subtle)", marginBottom: 8 }}>
            <div className="flex flex-col gap-3">
              <div>
                <p className="font-delius" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", marginBottom: 6 }}>Category</p>
                <div className="flex gap-2 flex-wrap">
                  {["All","Calculators","Textbooks","Lab Supplies","Supplies"].map(c => (
                    <button key={c} className={`pill ${category === c ? "active" : ""}`} style={{ fontSize: "var(--type-2xs)", padding: "3px 10px" }} onClick={() => setCategory(c)}>{c}</button>
                  ))}
                </div>
              </div>
              <div>
                <p className="font-delius" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", marginBottom: 6 }}>Condition</p>
                <div className="flex gap-2 flex-wrap">
                  {["All","New","Like New","Good","Fair"].map(c => (
                    <button key={c} className={`pill ${condition === c ? "active" : ""}`} style={{ fontSize: "var(--type-2xs)", padding: "3px 10px" }} onClick={() => setCondition(c)}>{c}</button>
                  ))}
                </div>
              </div>
              <div>
                <p className="font-delius" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", marginBottom: 4 }}>Max Price: P{maxPrice}</p>
                <input type="range" min={5} max={100} value={maxPrice} onChange={e => setMaxPrice(Number(e.target.value))} style={{ width: "100%", accentColor: "var(--accent)" }} />
              </div>
              <div>
                <p className="font-delius" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", marginBottom: 6 }}>Sort by</p>
                <div className="flex gap-2 flex-wrap">
                  {[["default","Relevance"],["price-asc","Price low"],["price-desc","Price high"],["rating","Rating"]].map(([v,l]) => (
                    <button key={v} className={`pill ${sortBy === v ? "active" : ""}`} style={{ fontSize: "var(--type-2xs)", padding: "3px 10px" }} onClick={() => setSortBy(v)}>{l}</button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}
        <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)" }}>{results.length} item{results.length !== 1 ? "s" : ""} found</p>
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "16px" }}>
        {results.length === 0 ? (
          <div style={{ textAlign: "center", paddingTop: 60 }}>
            <div style={{ color: "var(--bd-subtle)", display: "flex", justifyContent: "center", marginBottom: 12 }}>
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
            </div>
            <p className="font-chewy" style={{ color: "var(--tx-muted)", fontSize: "var(--type-md)" }}>No items found</p>
            <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", marginTop: 4 }}>Try adjusting your filters</p>
          </div>
        ) : (
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
            {results.map(p => (
              <div key={p.id} className="product-card" onClick={() => { setViewProduct(p); setScreen("product"); }}>
                <div style={{ height: 120, overflow: "hidden", background: "var(--bg-elevated)" }}>
                  <img src={p.image} alt={p.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                </div>
                <div style={{ padding: "10px 10px 12px" }}>
                  <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600, marginBottom: 4, lineHeight: 1.3 }}>{p.name}</p>
                  <div className="flex items-center gap-1 mb-2">
                    <Icon.Star filled />
                    <span className="font-mono" style={{ fontSize: "var(--type-2xs)", color: "var(--tx-muted)" }}>{p.rating} ({p.reviews})</span>
                  </div>
                  <span className="badge" style={{ display: "inline-block", marginBottom: 6 }}>{p.condition}</span>
                  <p className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>P{p.price.toFixed(2)}</p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}

// ─── Product Screen ───────────────────────────────────────────────────────────

function ProductScreen({ product, setScreen }: {
  product: Product; setScreen: (s: Screen) => void;
}) {
  const [favored, setFavored] = useState(false);

  const related = PRODUCTS.filter(p => p.category === product.category && p.id !== product.id).slice(0, 3);

  return (
    <div style={{ flex: 1, overflowY: "auto" }}>
      <div style={{ position: "relative", background: "var(--bg-elevated)", height: 260, flexShrink: 0 }}>
        <img src={product.image} alt={product.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to bottom, rgba(0,0,0,0.35) 0%, transparent 40%)" }} />
        <div style={{ position: "absolute", top: 14, left: 16, right: 16, display: "flex", justifyContent: "space-between" }}>
          <button style={S.iconBtn} onClick={() => setScreen("home")}><Icon.Back /></button>
          <button style={S.iconBtn} onClick={() => setFavored(!favored)}><Icon.Heart filled={favored} /></button>
        </div>
        <div style={{ position: "absolute", bottom: 12, left: 0, right: 0, display: "flex", justifyContent: "center", gap: 5 }}>
          {[0,1,2].map(i => <div key={i} style={{ width: i === 0 ? 18 : 6, height: 6, borderRadius: 3, background: i === 0 ? "var(--accent-hi)" : "rgba(255,255,255,0.4)" }} />)}
        </div>
      </div>

      <div style={{ background: "var(--bg-surface)", borderRadius: "20px 20px 0 0", marginTop: -16, paddingTop: 20 }}>
        <div className="px-5 pb-8">
          <div className="flex gap-2 mb-3 flex-wrap">
            <span className="badge purple">{product.category}</span>
            {product.course && <span className="badge">{product.course}</span>}
            <span className="badge">{product.condition}</span>
          </div>
          <h1 className="font-chewy" style={{ fontSize: "var(--type-md)", color: "var(--tx)", marginBottom: 8, lineHeight: 1.25, fontWeight: 600 }}>{product.name}</h1>
          <div className="flex items-center gap-3 mb-5">
            <span className="font-chewy" style={{ fontSize: "var(--type-lg)", color: "var(--accent-hi)", fontWeight: 700 }}>P{product.price.toFixed(2)}</span>
            <div className="flex items-center gap-1">
              <Icon.Star filled />
              <span className="font-mono" style={{ fontSize: "var(--type-xs)", color: "var(--tx-muted)" }}>{product.rating} ({product.reviews} reviews)</span>
            </div>
          </div>

          <div style={{ background: "var(--bg-elevated)", border: "1px solid var(--bd)", borderRadius: 14, padding: "12px 14px", display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
            <div style={{ width: 42, height: 42, background: "var(--bg-surface)", border: "1px solid var(--bd-subtle)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "0.82rem", fontWeight: 700 }}>{product.sellerAvatar}</span>
            </div>
            <div style={{ flex: 1 }}>
              <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600 }}>{product.seller}</p>
              <div className="flex items-center gap-1 mt-1">
                <Icon.Star filled />
                <span className="font-mono" style={{ fontSize: "var(--type-2xs)", color: "var(--tx-muted)" }}>4.8 · 12 items sold · UP Student</span>
              </div>
            </div>
            <button style={{ ...S.iconBtn, width: "auto", padding: "6px 12px", display: "flex", gap: 5 }} onClick={() => setScreen("messages")}>
              <Icon.Message /><span className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx-2)" }}>Chat</span>
            </button>
          </div>

          <div style={{ marginBottom: 20 }}>
            <h3 className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-sm)", marginBottom: 8, fontWeight: 600 }}>About this item</h3>
            <p className="font-opensans" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", lineHeight: 1.7 }}>{product.description}</p>
          </div>

          <div className="flex gap-3 mb-6">
            <button className="btn-secondary flex-1" onClick={() => setFavored(!favored)} style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}>
              <Icon.Heart filled={favored} /> Save Item
            </button>
            <button className="btn-primary flex-1" onClick={() => setScreen("messages")} style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}>
              Message Seller <Icon.Message />
            </button>
          </div>

          {related.length > 0 && (
            <div>
              <h3 className="section-title mb-3">Related Materials</h3>
              <div className="flex gap-3 overflow-x-auto pb-2" style={{ scrollbarWidth: "none" }}>
                {related.map(p => (
                  <div key={p.id} className="product-card" style={{ minWidth: 135, flexShrink: 0 }}>
                    <div style={{ height: 85, overflow: "hidden", background: "var(--bg-elevated)" }}>
                      <img src={p.image} alt={p.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                    </div>
                    <div style={{ padding: "8px 10px" }}>
                      <p className="font-opensans" style={{ fontSize: "var(--type-2xs)", color: "var(--tx)", fontWeight: 600, lineHeight: 1.3, marginBottom: 3 }}>{p.name}</p>
                      <p className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-xs)", fontWeight: 600 }}>P{p.price.toFixed(2)}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Cart Screen ──────────────────────────────────────────────────────────────

function CartScreen({ setScreen, cart, setCart }: { setScreen: (s: Screen) => void; cart: CartItem[]; setCart: (c: CartItem[]) => void }) {
  const updateQty = (id: number, delta: number) =>
    setCart(cart.map(c => c.product.id === id ? { ...c, qty: Math.max(0, c.qty + delta) } : c).filter(c => c.qty > 0));

  const subtotal = cart.reduce((s, c) => s + c.product.price * c.qty, 0);
  const fee = 10;
  const total = subtotal + fee;

  return (
    <>
      <div style={S.header}>
        <div className="flex items-center gap-3">
          <button style={S.iconBtn} onClick={() => setScreen("home")}><Icon.Back /></button>
          <span className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600 }}>Your Cart</span>
          <span className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)" }}>({cart.length} item{cart.length !== 1 ? "s" : ""})</span>
        </div>
      </div>

      {cart.length === 0 ? (
        <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: 40, textAlign: "center" }}>
          <div style={{ color: "var(--bd-subtle)", marginBottom: 16 }}>
            <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="9" cy="21" r="1" /><circle cx="20" cy="21" r="1" />
              <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6" />
            </svg>
          </div>
          <p className="font-chewy" style={{ color: "var(--tx-muted)", fontSize: "var(--type-md)", marginBottom: 6 }}>Cart is empty</p>
          <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", marginBottom: 24 }}>Browse items from fellow students.</p>
          <button className="btn-primary" style={{ display: "flex", alignItems: "center", gap: 6 }} onClick={() => setScreen("search")}>
            Browse Items <Icon.ArrowRight />
          </button>
        </div>
      ) : (
        <>
          <div style={{ flex: 1, overflowY: "auto", padding: "16px", display: "flex", flexDirection: "column", gap: 12 }}>
            {cart.map(({ product, qty }) => (
              <div key={product.id} style={{ ...S.card, padding: "12px", display: "flex", gap: 12 }}>
                <div style={{ width: 66, height: 66, borderRadius: 10, overflow: "hidden", background: "var(--bg-elevated)", flexShrink: 0 }}>
                  <img src={product.image} alt={product.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                </div>
                <div style={{ flex: 1 }}>
                  <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600, lineHeight: 1.3, marginBottom: 4 }}>{product.name}</p>
                  <span className="badge" style={{ display: "inline-block", marginBottom: 8 }}>{product.condition}</span>
                  <div className="flex items-center justify-between">
                    <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>P{(product.price * qty).toFixed(2)}</span>
                    <div style={{ display: "flex", alignItems: "center", gap: 8, background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 8, padding: "4px 8px" }}>
                      <button style={{ background: "none", border: "none", cursor: "pointer", color: "var(--tx-2)", display: "flex" }} onClick={() => updateQty(product.id, -1)}><Icon.Minus /></button>
                      <span className="font-mono" style={{ color: "var(--tx)", fontSize: "var(--type-sm)", minWidth: 16, textAlign: "center" }}>{qty}</span>
                      <button style={{ background: "none", border: "none", cursor: "pointer", color: "var(--tx-2)", display: "flex" }} onClick={() => updateQty(product.id, 1)}><Icon.Plus /></button>
                    </div>
                  </div>
                </div>
              </div>
            ))}
            <div style={{ ...S.card, padding: "16px" }}>
              <h3 className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-sm)", fontWeight: 600, marginBottom: 12 }}>Order Summary</h3>
              <div className="flex flex-col gap-2 font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx-2)" }}>
                <div className="flex justify-between"><span>Subtotal</span><span>P{subtotal.toFixed(2)}</span></div>
                <div className="flex justify-between"><span>Service fee</span><span>P{fee.toFixed(2)}</span></div>
                <div style={{ borderTop: "1px solid var(--bd)", paddingTop: 10, marginTop: 4 }} className="flex justify-between">
                  <span className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-sm)", fontWeight: 600 }}>Total</span>
                  <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>P{total.toFixed(2)}</span>
                </div>
              </div>
            </div>
          </div>
          <div style={{ padding: "12px 16px 20px", background: "var(--bg-surface)", borderTop: "1px solid var(--bd)", flexShrink: 0 }}>
            <button className="btn-primary w-full" style={{ padding: "13px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }} onClick={() => setScreen("checkout")}>
              Proceed to Checkout <Icon.ArrowRight />
            </button>
          </div>
        </>
      )}
    </>
  );
}

// ─── Checkout Screen ──────────────────────────────────────────────────────────

function CheckoutScreen({ setScreen, cart, setCart }: { setScreen: (s: Screen) => void; cart: CartItem[]; setCart: (c: CartItem[]) => void }) {
  const [meetup, setMeetup]   = useState("campus");
  const [address, setAddress] = useState("");
  const [payment, setPayment] = useState("gcash");
  const [placing, setPlacing] = useState(false);

  const total = cart.reduce((s, c) => s + c.product.price * c.qty, 0) + 10;

  const placeOrder = () => {
    setPlacing(true);
    setTimeout(() => { setCart([]); setScreen("confirmation"); }, 1200);
  };

  const RadioRow = ({ name, val, current, set, label, sub }: { name: string; val: string; current: string; set: (v: string) => void; label: string; sub?: string }) => (
    <label style={{ display: "flex", gap: 12, alignItems: "flex-start", cursor: "pointer", background: current === val ? "var(--bg-elevated)" : "transparent", border: `1px solid ${current === val ? "var(--bd-subtle)" : "transparent"}`, borderRadius: 10, padding: "10px 12px" }}>
      <input type="radio" name={name} checked={current === val} onChange={() => set(val)} style={{ accentColor: "var(--accent)", marginTop: 2 }} />
      <div>
        <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 600 }}>{label}</p>
        {sub && <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)" }}>{sub}</p>}
      </div>
    </label>
  );

  return (
    <>
      <div style={S.header}>
        <div className="flex items-center gap-3">
          <button style={S.iconBtn} onClick={() => setScreen("cart")}><Icon.Back /></button>
          <span className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600 }}>Checkout</span>
        </div>
      </div>
      <div style={{ flex: 1, overflowY: "auto", padding: "16px", display: "flex", flexDirection: "column", gap: 14 }}>
        <div style={{ ...S.card, padding: "16px" }}>
          <h3 className="font-chewy flex items-center gap-2" style={{ color: "var(--tx)", fontSize: "var(--type-sm)", fontWeight: 600, marginBottom: 12 }}><Icon.MapPin /> Delivery Method</h3>
          <div className="flex flex-col gap-1">
            <RadioRow name="meetup" val="campus" current={meetup} set={setMeetup} label="Campus Meetup" sub="Meet at the university gates or library" />
            <RadioRow name="meetup" val="address" current={meetup} set={setMeetup} label="Home Delivery" sub="Ship to your address (+P50 fee)" />
          </div>
          {meetup === "address" && (
            <div style={{ marginTop: 8 }}><input className="input-field w-full" placeholder="Enter delivery address" value={address} onChange={e => setAddress(e.target.value)} /></div>
          )}
          {meetup === "campus" && (
            <div style={{ marginTop: 8, background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 8, padding: "8px 12px", display: "flex", gap: 6, alignItems: "center" }}>
              <span style={{ color: "var(--tx-muted)" }}><Icon.Location /></span>
              <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx-2)" }}>Suggested: University Main Library, Ground Floor</p>
            </div>
          )}
        </div>

        <div style={{ ...S.card, padding: "16px" }}>
          <h3 className="font-chewy flex items-center gap-2" style={{ color: "var(--tx)", fontSize: "var(--type-sm)", fontWeight: 600, marginBottom: 12 }}><Icon.Wallet /> Payment Method</h3>
          <div className="flex flex-col gap-1">
            <RadioRow name="pay" val="gcash" current={payment} set={setPayment} label="GCash" />
            <RadioRow name="pay" val="cash" current={payment} set={setPayment} label="Cash on Meetup" />
            <RadioRow name="pay" val="maya" current={payment} set={setPayment} label="Maya" />
          </div>
        </div>

        <div style={{ ...S.card, padding: "16px" }}>
          <h3 className="font-chewy flex items-center gap-2" style={{ color: "var(--tx)", fontSize: "var(--type-sm)", fontWeight: 600, marginBottom: 10 }}><Icon.Package /> Items</h3>
          {cart.map(({ product, qty }) => (
            <div key={product.id} className="flex justify-between items-center mb-2">
              <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx-2)", flex: 1, marginRight: 8 }}>{product.name} x{qty}</p>
              <span className="font-mono" style={{ color: "var(--accent-hi)", fontSize: "var(--type-xs)", fontWeight: 500 }}>P{(product.price * qty).toFixed(2)}</span>
            </div>
          ))}
          <div style={{ borderTop: "1px solid var(--bd)", paddingTop: 10, marginTop: 6 }} className="flex justify-between">
            <span className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-sm)", fontWeight: 600 }}>Total</span>
            <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>P{total.toFixed(2)}</span>
          </div>
        </div>
      </div>
      <div style={{ padding: "12px 16px 20px", background: "var(--bg-surface)", borderTop: "1px solid var(--bd)", flexShrink: 0 }}>
        <button className="btn-primary w-full" style={{ padding: "13px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }} onClick={placeOrder} disabled={placing}>
          <Icon.Send />{placing ? "Placing Order..." : "Place Order"}
        </button>
      </div>
    </>
  );
}

// ─── Confirmation Screen ──────────────────────────────────────────────────────

function ConfirmationScreen({ setScreen }: { setScreen: (s: Screen) => void }) {
  const orderNum = useState(() => Math.floor(Math.random() * 9000) + 1000)[0];

  return (
    <div style={{ flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", background: "var(--bg)", padding: "40px 28px", textAlign: "center" }}>
      <div className="animate-bounce-in">
        <div style={{ width: 96, height: 96, background: "var(--accent)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", border: "1px solid var(--accent-lo)", boxShadow: "0 6px 24px var(--shadow-accent)", margin: "0 auto 24px", color: "var(--accent-tx)" }}>
          <Icon.Check size={44} />
        </div>
      </div>
      <h1 className="font-chewy" style={{ fontSize: "var(--type-xl)", color: "var(--tx)", fontWeight: 700, letterSpacing: "-0.02em", marginBottom: 8 }}>Order Placed</h1>
      <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", marginBottom: 28 }}>Your campus swap is confirmed.</p>

      <div className="sticky-note" style={{ width: "100%", maxWidth: 340, marginBottom: 24, textAlign: "left" }}>
        <div style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
          <div style={{ color: "var(--tx-muted)", flexShrink: 0, marginTop: 2 }}><Icon.Inbox /></div>
          <div>
            <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700, marginBottom: 8 }}>What happens next</p>
            <div className="flex flex-col gap-2">
              {([
                ["CheckCircle", "Seller has been notified"],
                ["MapPin",      "Meetup details sent via chat"],
                ["Clock",       "Expected exchange: 1-2 days"],
                ["Message",     "Chat with seller anytime"],
              ] as const).map(([ic, text], i) => {
                const IcComp = Icon[ic] as () => React.JSX.Element;
                return (
                  <div key={i} className="flex items-center gap-2">
                    <span style={{ color: "var(--accent-hi)", display: "flex", flexShrink: 0 }}><IcComp /></span>
                    <span className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx-2)" }}>{text}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      <div style={{ ...S.card, display: "inline-block", padding: "8px 20px", marginBottom: 28 }}>
        <p className="font-mono" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)" }}>Order #CSW-{orderNum}</p>
      </div>

      <div className="flex flex-col gap-3 w-full" style={{ maxWidth: 340 }}>
        <button className="btn-primary w-full" style={{ padding: "13px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }} onClick={() => setScreen("home")}>
          <Icon.Home /> Back to Home
        </button>
        <button className="btn-secondary w-full" style={{ padding: "13px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }} onClick={() => setScreen("search")}>
          <Icon.ShoppingBag /> Keep Shopping
        </button>
      </div>
    </div>
  );
}

// ─── Seller Screen ────────────────────────────────────────────────────────────

// Messages Screen

function MessagesScreen() {
  const [activeChat, setActiveChat] = useState<(typeof CONVERSATIONS)[number] | null>(null);

  if (activeChat) {
    return (
      <>
        <div style={S.header}>
          <div className="flex items-center gap-3">
            <button style={S.iconBtn} onClick={() => setActiveChat(null)}><Icon.Back /></button>
            <div style={{ position: "relative", width: 40, height: 40, flexShrink: 0 }}>
              <div style={{ width: "100%", height: "100%", background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center" }}>
                <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-xs)", fontWeight: 700 }}>{activeChat.avatar}</span>
              </div>
              {activeChat.online && <span style={{ position: "absolute", right: 0, bottom: 1, width: 10, height: 10, borderRadius: "50%", background: "var(--success-color)", border: "2px solid var(--bg-surface)" }} />}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700 }}>{activeChat.name}</p>
              <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>Re: {activeChat.item}</p>
            </div>
          </div>
        </div>

        <div style={{ flex: 1, overflowY: "auto", padding: "14px 16px", display: "flex", flexDirection: "column", gap: 12, background: "var(--bg)" }}>
          <div style={{ ...S.card, padding: "12px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            <div>
              <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginBottom: 2 }}>Meetup</p>
              <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 600 }}>{activeChat.place}</p>
            </div>
            <div>
              <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginBottom: 2 }}>Time</p>
              <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 600 }}>{activeChat.meetupTime}</p>
            </div>
          </div>

          <div className="flex flex-col gap-2">
            {activeChat.messages.map((message, i) => {
              const mine = message.from === "me";
              return (
                <div key={`${message.time}-${i}`} style={{ display: "flex", justifyContent: mine ? "flex-end" : "flex-start" }}>
                  <div style={{ maxWidth: "78%", background: mine ? "var(--accent)" : "var(--bg-surface)", color: mine ? "var(--accent-tx)" : "var(--tx-2)", border: `1px solid ${mine ? "var(--accent-lo)" : "var(--bd)"}`, borderRadius: mine ? "14px 14px 4px 14px" : "14px 14px 14px 4px", padding: "9px 12px", boxShadow: "0 2px 8px var(--shadow-card)" }}>
                    <p className="font-opensans" style={{ fontSize: "var(--type-xs)", lineHeight: 1.5 }}>{message.text}</p>
                    <p className="font-mono" style={{ fontSize: "var(--type-2xs)", color: mine ? "rgba(255,255,255,0.72)" : "var(--tx-muted)", textAlign: "right", marginTop: 4 }}>{message.time}</p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div style={{ padding: "10px 16px 14px", background: "var(--bg-surface)", borderTop: "1px solid var(--bd)", flexShrink: 0 }}>
          <div className="flex gap-2">
            <input className="input-field" style={{ flex: 1, fontSize: "var(--type-xs)", padding: "10px 12px" }} placeholder="Write a message..." />
            <button className="btn-primary" style={{ width: 44, padding: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon.Send />
            </button>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <div style={S.header}>
        <div className="flex items-center justify-between mb-3">
          <span className="font-chewy flex items-center gap-2" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600 }}>
            <span style={{ color: "var(--accent-hi)" }}><Icon.Message size={20} /></span> Messages
          </span>
          <button style={S.iconBtn}><Icon.Search /></button>
        </div>
        <div style={{ background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 12, padding: "9px 12px", display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ color: "var(--success-color)", display: "flex" }}><Icon.CheckCircle /></span>
          <p className="font-opensans" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)" }}>3 active handoffs this week</p>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "16px", display: "flex", flexDirection: "column", gap: 16 }}>
        <div>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.Inbox /> Recent Chats</h3>
          <div className="flex flex-col gap-2">
            {CONVERSATIONS.map((chat, i) => (
              <button key={chat.name} onClick={() => setActiveChat(chat)} style={{ ...S.card, padding: "12px", display: "flex", gap: 11, alignItems: "center", borderColor: i === 0 ? "var(--accent-lo)" : "var(--bd)", width: "100%", textAlign: "left", cursor: "pointer" }}>
                <div style={{ position: "relative", width: 42, height: 42, flexShrink: 0 }}>
                  <div style={{ width: "100%", height: "100%", background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-xs)", fontWeight: 700 }}>{chat.avatar}</span>
                  </div>
                  {chat.online && <span style={{ position: "absolute", right: 0, bottom: 1, width: 10, height: 10, borderRadius: "50%", background: "var(--success-color)", border: "2px solid var(--bg-surface)" }} />}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="flex items-center justify-between gap-2">
                    <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700 }}>{chat.name}</p>
                    <span className="font-mono" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", flexShrink: 0 }}>{chat.time}</span>
                  </div>
                  <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", margin: "2px 0" }}>Re: {chat.item}</p>
                  <p className="font-opensans" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{chat.last}</p>
                </div>
                {chat.unread > 0 && (
                  <span style={{ background: "var(--accent)", color: "var(--accent-tx)", borderRadius: 999, minWidth: 20, height: 20, padding: "0 6px", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "var(--type-2xs)", fontFamily: "var(--font-mono)" }}>{chat.unread}</span>
                )}
              </button>
            ))}
          </div>
        </div>

        <div>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.MapPin /> Handoff Details</h3>
          <div style={{ ...S.card, padding: "14px", display: "flex", flexDirection: "column", gap: 12 }}>
            <div className="flex items-start gap-3">
              <div style={{ width: 38, height: 38, background: "var(--accent)", color: "var(--accent-tx)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                <Icon.Message />
              </div>
              <div>
                <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700 }}>{CONVERSATIONS[0].name}</p>
                <p className="font-opensans" style={{ color: "var(--tx-2)", fontSize: "var(--type-xs)", lineHeight: 1.5 }}>{CONVERSATIONS[0].last}</p>
              </div>
            </div>
            <div style={{ background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 10, padding: "10px 12px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              <div>
                <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginBottom: 2 }}>Place</p>
                <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 600 }}>{CONVERSATIONS[0].place}</p>
              </div>
              <div>
                <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginBottom: 2 }}>Time</p>
                <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 600 }}>{CONVERSATIONS[0].meetupTime}</p>
              </div>
            </div>
            <button className="btn-secondary w-full" style={{ padding: "10px", display: "flex", alignItems: "center", justifyContent: "center", gap: 7 }} onClick={() => setActiveChat(CONVERSATIONS[0])}>
              Open Chat <Icon.ArrowRight />
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

// Profile Screen

function ProfileScreen({ setScreen }: { setScreen: (s: Screen) => void }) {
  const [notificationsOn, setNotificationsOn] = useState(true);
  const [availableForChat, setAvailableForChat] = useState(true);

  const Toggle = ({ enabled, onClick }: { enabled: boolean; onClick: () => void }) => (
    <button
      onClick={onClick}
      style={{
        width: 42,
        height: 24,
        borderRadius: 999,
        border: `1px solid ${enabled ? "var(--accent-lo)" : "var(--bd-subtle)"}`,
        background: enabled ? "var(--accent)" : "var(--bg-elevated)",
        padding: 2,
        cursor: "pointer",
        display: "flex",
        justifyContent: enabled ? "flex-end" : "flex-start",
        flexShrink: 0,
      }}
    >
      <span style={{ width: 18, height: 18, borderRadius: "50%", background: enabled ? "var(--accent-tx)" : "var(--tx-muted)", display: "block" }} />
    </button>
  );

  const SettingsRow = ({ icon, title, detail, action }: { icon: ReactNode; title: string; detail: string; action?: ReactNode }) => (
    <div className="flex items-center gap-3" style={{ padding: "12px 0", borderBottom: "1px solid var(--bd)" }}>
      <div style={{ width: 32, height: 32, borderRadius: 9, background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", color: "var(--accent-hi)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
        {icon}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700 }}>{title}</p>
        <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginTop: 2 }}>{detail}</p>
      </div>
      {action ?? <Icon.ArrowRight />}
    </div>
  );

  return (
    <>
      <div style={S.header}>
        <div className="flex items-center justify-between">
          <span className="font-chewy flex items-center gap-2" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600 }}>
            <span style={{ color: "var(--accent-hi)" }}><Icon.User /></span> Profile
          </span>
          <button style={S.iconBtn}><Icon.Pencil /></button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "16px", display: "flex", flexDirection: "column", gap: 16 }}>
        <div style={{ ...S.card, padding: "18px" }}>
          <div className="flex items-center gap-4 mb-4">
            <div style={{ width: 68, height: 68, background: "var(--accent)", border: "1px solid var(--accent-lo)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--accent-tx)", flexShrink: 0 }}>
              <span className="font-chewy" style={{ fontSize: "var(--type-md)", fontWeight: 700 }}>{USER_PROFILE.avatar}</span>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <h1 className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600, marginBottom: 3 }}>{USER_PROFILE.name}</h1>
              <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", marginBottom: 8 }}>{USER_PROFILE.email}</p>
              <div className="flex items-center gap-3">
                <span className="font-mono" style={{ color: "var(--accent-hi)", fontSize: "var(--type-xs)" }}>{USER_PROFILE.rating} rating</span>
                <span className="font-mono" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)" }}>{USER_PROFILE.swaps} swaps</span>
              </div>
            </div>
          </div>
          <button className="btn-primary w-full" style={{ padding: "12px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }} onClick={() => setScreen("sellerHub")}>
            <Icon.Store /> Seller Hub
          </button>
        </div>

        <div>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.BookOpen /> Academic Info</h3>
          <div style={{ ...S.card, padding: "14px", display: "grid", gap: 10 }}>
            {[
              ["Faculty", USER_PROFILE.faculty],
              ["Major", USER_PROFILE.major],
              ["Semester", USER_PROFILE.semester],
              ["Campus", USER_PROFILE.campus],
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between gap-3" style={{ borderBottom: label === "Campus" ? "none" : "1px solid var(--bd)", paddingBottom: label === "Campus" ? 0 : 10 }}>
                <span className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)" }}>{label}</span>
                <span className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 600, textAlign: "right" }}>{value}</span>
              </div>
            ))}
          </div>
        </div>

        <div>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.Pencil /> Profile Settings</h3>
          <div style={{ ...S.card, padding: "2px 14px" }}>
            <SettingsRow icon={<Icon.User />} title="Personal Information" detail="Name, avatar, email, faculty, major, and semester" />
            <SettingsRow icon={<Icon.Bell />} title="Notifications" detail="Messages, offers, handoff reminders" action={<Toggle enabled={notificationsOn} onClick={() => setNotificationsOn(v => !v)} />} />
            <SettingsRow icon={<Icon.Message />} title="Chat Availability" detail="Show sellers and buyers when you are reachable" action={<Toggle enabled={availableForChat} onClick={() => setAvailableForChat(v => !v)} />} />
            <SettingsRow icon={<Icon.Wallet />} title="Payment Methods" detail="GCash, Maya, cash preferences, and payout info" />
            <SettingsRow icon={<Icon.MapPin />} title="Meetup Locations" detail="Saved handoff spots around campus" />
            <SettingsRow icon={<Icon.CheckCircle />} title="Privacy and Safety" detail="Blocked users, report history, and account visibility" />
            <SettingsRow icon={<Icon.Inbox />} title="Help and Support" detail="Campus Swap support, FAQs, and dispute help" />
            <button className="w-full flex items-center gap-3" style={{ padding: "12px 0", background: "none", border: "none", color: "var(--error-color)", cursor: "pointer", textAlign: "left" }}>
              <div style={{ width: 32, height: 32, borderRadius: 9, background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                <Icon.Back />
              </div>
              <div style={{ flex: 1 }}>
                <p className="font-opensans" style={{ fontSize: "var(--type-xs)", fontWeight: 700 }}>Sign Out</p>
                <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginTop: 2 }}>End this session on the device</p>
              </div>
            </button>
          </div>
        </div>

        <div style={{ marginBottom: 8 }}>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.ShoppingBag /> Purchase History</h3>
          <div className="flex flex-col gap-3">
            {PURCHASE_HISTORY.map(({ product, seller, date, status }) => (
              <div key={product.id} style={{ ...S.card, padding: "12px", display: "flex", gap: 10, alignItems: "center" }}>
                <div style={{ width: 56, height: 56, borderRadius: 10, overflow: "hidden", background: "var(--bg-elevated)", flexShrink: 0 }}>
                  <img src={product.image} alt={product.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700, marginBottom: 3, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{product.name}</p>
                  <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginBottom: 5 }}>From {seller} - {date}</p>
                  <span style={{ background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 6, padding: "2px 8px", fontSize: "var(--type-2xs)", color: "var(--success-color)", fontFamily: "var(--font-body)", fontWeight: 500 }}>{status}</span>
                </div>
                <span className="font-mono" style={{ color: "var(--accent-hi)", fontSize: "var(--type-xs)", fontWeight: 600 }}>P{product.price.toFixed(2)}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}

// New Listing Screen

function NewListingScreen({ setScreen }: { setScreen: (s: Screen) => void }) {
  const [listing, setListing] = useState({
    title: "",
    description: "",
    courseCode: "",
    price: "",
    condition: "GOOD" as ListingCondition,
  });
  const [successMsg, setSuccessMsg] = useState("");
  const [photoCount, setPhotoCount] = useState(0);
  const [aiReady, setAiReady] = useState(false);

  const canPublish = listing.title.trim() && listing.description.trim() && listing.courseCode.trim() && listing.price.trim();
  const conditionLabels: Record<ListingCondition, string> = {
    NEW: "NEW",
    LIKE_NEW: "LIKE_NEW",
    GOOD: "GOOD",
    FAIR: "FAIR",
  };
  const aiSuggestion = { condition: "LIKE_NEW" as ListingCondition, price: "22.00", confidence: "92%" };

  const handlePhotoSelect = (count: number) => {
    const nextCount = count || 1;
    setPhotoCount(nextCount);
    setAiReady(true);
  };

  const applyAiSuggestion = () => {
    setListing({ ...listing, condition: aiSuggestion.condition, price: aiSuggestion.price });
  };

  const publishListing = () => {
    if (!canPublish) return;
    setSuccessMsg(`"${listing.title}" is ready for campus buyers.`);
    setTimeout(() => setScreen("sellerHub"), 900);
  };

  return (
    <>
      <div style={S.header}>
        <div className="flex items-center gap-3">
          <button style={S.iconBtn} onClick={() => setScreen("sellerHub")} title="Back to Seller Hub">
            <Icon.Back />
          </button>
          <span className="font-chewy flex items-center gap-2" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600 }}>
            <span style={{ color: "var(--accent-hi)" }}><Icon.Sell /></span> List New Item
          </span>
        </div>
      </div>

      {successMsg && (
        <div style={{ background: "var(--bg-elevated)", borderBottom: "1px solid var(--bd)", padding: "10px 18px", flexShrink: 0 }}>
          <p className="font-opensans flex items-center justify-center gap-2" style={{ color: "var(--success-color)", fontSize: "var(--type-xs)" }}>
            <Icon.CheckCircle /> {successMsg}
          </p>
        </div>
      )}

      <div style={{ flex: 1, overflowY: "auto", padding: "16px", display: "flex", flexDirection: "column", gap: 16 }}>
        <div style={{ ...S.card, padding: "16px", border: "1px solid var(--accent-lo)", boxShadow: "0 6px 22px var(--shadow-accent)" }}>
          <div className="flex items-start justify-between gap-3 mb-3">
            <div>
              <h3 className="section-title flex items-center gap-2" style={{ marginBottom: 4 }}><Icon.Sparkle /> AI Photo Scan</h3>
              <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", lineHeight: 1.5 }}>
                Add clear photos and AI will estimate the item condition and suggest a fair campus resale price.
              </p>
            </div>
            <span className="badge purple" style={{ flexShrink: 0 }}>AI</span>
          </div>

          <div style={{ background: "var(--bg-elevated)", border: "1px dashed var(--accent-hi)", borderRadius: 14, padding: "16px", marginBottom: 12 }}>
            <div className="flex items-center gap-3 mb-4">
              <div style={{ width: 54, height: 54, borderRadius: 14, background: "var(--accent)", color: "var(--accent-tx)", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 4px 14px var(--shadow-accent)", flexShrink: 0 }}>
                <Icon.Camera />
              </div>
              <div>
                <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700 }}>Upload item pictures</p>
                <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginTop: 3 }}>
                  Front, back, pages, labels, scratches, and accessories help the AI judge condition.
                </p>
              </div>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              <label className="btn-primary" style={{ padding: "12px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8, fontSize: "var(--type-xs)", cursor: "pointer" }}>
                <Icon.Image /> Gallery
                <input type="file" accept="image/*" multiple style={{ display: "none" }} onChange={e => handlePhotoSelect(e.target.files?.length ?? 0)} />
              </label>
              <label className="btn-secondary" style={{ padding: "12px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8, fontSize: "var(--type-xs)", cursor: "pointer" }}>
                <Icon.Camera /> Camera
                <input type="file" accept="image/*" capture="environment" style={{ display: "none" }} onChange={e => handlePhotoSelect(e.target.files?.length ?? 0)} />
              </label>
            </div>

            <div className="flex gap-2 mt-3">
              {[0, 1, 2].map(i => (
                <div key={i} style={{ height: 48, flex: 1, borderRadius: 10, background: i < photoCount ? "var(--tag-bg)" : "var(--bg-surface)", border: "1px solid var(--bd-subtle)", display: "flex", alignItems: "center", justifyContent: "center", color: i < photoCount ? "var(--accent-hi)" : "var(--tx-muted)" }}>
                  {i < photoCount ? <Icon.CheckCircle /> : <Icon.Image />}
                </div>
              ))}
            </div>
          </div>

          <div style={{ background: "var(--bg-surface)", border: "1px solid var(--bd)", borderRadius: 12, padding: "12px" }}>
            {aiReady ? (
              <div>
                <div className="flex items-center justify-between gap-3 mb-3">
                  <div>
                    <p className="font-opensans" style={{ color: "var(--tx)", fontSize: "var(--type-xs)", fontWeight: 700 }}>AI recommendation ready</p>
                    <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginTop: 2 }}>{aiSuggestion.confidence} confidence from {photoCount} photo{photoCount === 1 ? "" : "s"}</p>
                  </div>
                  <button className="btn-secondary" style={{ padding: "7px 10px", fontSize: "var(--type-2xs)" }} onClick={applyAiSuggestion}>Apply</button>
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                  <div style={{ background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 9, padding: "9px 10px" }}>
                    <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginBottom: 3 }}>Detected condition</p>
                    <p className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>{aiSuggestion.condition}</p>
                  </div>
                  <div style={{ background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 9, padding: "9px 10px" }}>
                    <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", marginBottom: 3 }}>Suggested price</p>
                    <p className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>P{aiSuggestion.price}</p>
                  </div>
                </div>
              </div>
            ) : (
              <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-xs)", lineHeight: 1.5 }}>
                Waiting for photos. Once added, AI will suggest condition and price before you publish.
              </p>
            )}
          </div>
        </div>

        <div style={{ ...S.card, padding: "16px", display: "flex", flexDirection: "column", gap: 12 }}>
          <div>
            <label className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", display: "block", marginBottom: 6 }}>Title</label>
            <input className="input-field w-full" placeholder="e.g. Organic Chemistry Textbook" value={listing.title} onChange={e => setListing({ ...listing, title: e.target.value })} />
          </div>
          <div>
            <label className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", display: "block", marginBottom: 6 }}>Description</label>
            <textarea className="input-field w-full" placeholder="Condition notes, what is included, and meetup details..." value={listing.description} onChange={e => setListing({ ...listing, description: e.target.value })} rows={4} style={{ resize: "none", lineHeight: 1.5 }} />
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            <div>
              <label className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", display: "block", marginBottom: 6 }}>Course Code</label>
              <input className="input-field w-full" placeholder="CS 301" value={listing.courseCode} onChange={e => setListing({ ...listing, courseCode: e.target.value.toUpperCase() })} />
            </div>
            <div>
              <label className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", display: "block", marginBottom: 6 }}>Price</label>
              <input className="input-field w-full" placeholder="P0.00" type="number" min="0" value={listing.price} onChange={e => setListing({ ...listing, price: e.target.value })} />
            </div>
          </div>
        </div>

        <div>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.Tag /> Condition</h3>
          <div style={{ ...S.card, padding: "14px" }}>
            <div className="flex gap-2 flex-wrap">
              {(Object.keys(conditionLabels) as ListingCondition[]).map(condition => (
                <button key={condition} className={`pill ${listing.condition === condition ? "active" : ""}`} onClick={() => setListing({ ...listing, condition })}>
                  {conditionLabels[condition]}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div style={{ padding: "12px 16px 20px", background: "var(--bg-surface)", borderTop: "1px solid var(--bd)", flexShrink: 0 }}>
        <button className="btn-primary w-full" style={{ padding: "13px", display: "flex", alignItems: "center", justifyContent: "center", gap: 8, opacity: canPublish ? 1 : 0.65 }} onClick={publishListing}>
          <Icon.Send /> Publish Listing
        </button>
      </div>
    </>
  );
}

// Seller Hub Screen
function SellerScreen({ setScreen, setViewProduct }: { setScreen: (s: Screen) => void; setViewProduct: (p: Product) => void }) {
  const myListings  = PRODUCTS.filter(p => p.seller === "Maria Santos");
  const recentSales = PRODUCTS.slice(0, 2);
  const messages = [
    { from: "Jake Reyes", item: "Casio fx-991EX",   msg: "Is this still available?",    time: "2m ago" },
    { from: "Sofia Lim",  item: "Organic Chemistry", msg: "Can we meet at the library?", time: "1h ago" },
    { from: "Leo Tan",    item: "Lab Coat",           msg: "What size is this?",          time: "3h ago" },
  ];

  return (
    <>
      <div style={S.header}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button style={S.iconBtn} onClick={() => setScreen("profile")} title="Back to profile">
              <Icon.Back />
            </button>
            <span className="font-chewy flex items-center gap-2" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600 }}>
              <span style={{ color: "var(--accent-hi)" }}><Icon.Store /></span> My Seller Hub
            </span>
          </div>
          <button className="btn-primary" style={{ padding: "7px 14px", fontSize: "var(--type-xs)", display: "flex", alignItems: "center", gap: 6 }} onClick={() => setScreen("newListing")}>
            <Icon.Plus /> Add Item
          </button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "16px", display: "flex", flexDirection: "column", gap: 16 }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10 }}>
          {([
            ["Package",    "8",    "Active Listings"],
            ["Wallet",     "P240", "Earned This Month"],
            ["TrendingUp", "4.9",  "Your Rating"],
          ] as const).map(([ic, val, label]) => {
            const IcComp = Icon[ic] as () => ReactNode;
            return (
              <div key={val} style={{ ...S.card, padding: "12px 8px", textAlign: "center" }}>
                <div style={{ color: "var(--accent-hi)", display: "flex", justifyContent: "center", marginBottom: 4 }}><IcComp /></div>
                <p className="font-chewy" style={{ color: "var(--tx)", fontSize: "var(--type-md)", fontWeight: 600 }}>{val}</p>
                <p className="font-opensans" style={{ color: "var(--tx-muted)", fontSize: "var(--type-2xs)", lineHeight: 1.3, marginTop: 2 }}>{label}</p>
              </div>
            );
          })}
        </div>

        <div>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.Package /> Active Listings</h3>
          <div className="flex flex-col gap-3">
            {myListings.map(p => (
              <div key={p.id} style={{ ...S.card, padding: "12px", display: "flex", gap: 10, cursor: "pointer" }}
                onClick={() => { setViewProduct(p); setScreen("product"); }}>
                <div style={{ width: 58, height: 58, borderRadius: 10, overflow: "hidden", background: "var(--bg-elevated)", flexShrink: 0 }}>
                  <img src={p.image} alt={p.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                </div>
                <div style={{ flex: 1 }}>
                  <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600, marginBottom: 3, lineHeight: 1.3 }}>{p.name}</p>
                  <div className="flex items-center gap-2 mb-2">
                    <span className="badge">{p.condition}</span>
                    <div style={{ display: "flex", alignItems: "center", gap: 3, color: "var(--tx-muted)" }}>
                      <Icon.Eye /><span className="font-mono" style={{ fontSize: "var(--type-2xs)" }}>24 views</span>
                    </div>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-sm)", fontWeight: 600 }}>P{p.price.toFixed(2)}</span>
                    <span style={{ background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: 6, padding: "2px 8px", fontSize: "var(--type-2xs)", color: "var(--success-color)", fontFamily: "var(--font-body)", fontWeight: 500 }}>Active</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.TrendingUp /> Recent Sales</h3>
          <div className="flex flex-col gap-2">
            {recentSales.map(p => (
              <div key={p.id} style={{ ...S.card, padding: "10px 14px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600 }}>{p.name}</p>
                  <p className="font-opensans" style={{ fontSize: "var(--type-2xs)", color: "var(--tx-muted)" }}>Sold to Ana Cruz · 2 days ago</p>
                </div>
                <span className="font-mono" style={{ color: "var(--accent-hi)", fontSize: "var(--type-xs)", fontWeight: 500 }}>P{p.price.toFixed(2)}</span>
              </div>
            ))}
          </div>
        </div>

        <div style={{ marginBottom: 8 }}>
          <h3 className="section-title flex items-center gap-2 mb-3"><Icon.Message /> Buyer Messages</h3>
          <div className="flex flex-col gap-2">
            {messages.map((m, i) => (
              <div key={i} style={{ ...S.card, padding: "10px 14px", cursor: "pointer" }}>
                <div className="flex items-center justify-between mb-1">
                  <div className="flex items-center gap-2">
                    <div style={{ width: 28, height: 28, background: "var(--bg-elevated)", border: "1px solid var(--bd-subtle)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center" }}>
                      <span className="font-chewy" style={{ color: "var(--accent-hi)", fontSize: "var(--type-2xs)", fontWeight: 700 }}>{m.from.split(" ").map(n => n[0]).join("")}</span>
                    </div>
                    <span className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx)", fontWeight: 600 }}>{m.from}</span>
                  </div>
                  <span className="font-mono" style={{ fontSize: "var(--type-2xs)", color: "var(--tx-muted)" }}>{m.time}</span>
                </div>
                <p className="font-opensans" style={{ fontSize: "var(--type-2xs)", color: "var(--tx-muted)", marginBottom: 2 }}>Re: {m.item}</p>
                <p className="font-opensans" style={{ fontSize: "var(--type-xs)", color: "var(--tx-2)" }}>{m.msg}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}

// ─── App ─────────────────────────────────────────────────────────────────────

export default function App() {
  const [screen, setScreen]           = useState<Screen>("login");
  const [loggedIn, setLoggedIn]       = useState(false);
  const [viewProduct, setViewProduct] = useState<Product | null>(null);
  const [cart, setCart]               = useState<CartItem[]>([]);
  const [theme, setTheme]             = useState<Theme>("dark");

  const handleLogin  = () => { setLoggedIn(true); setScreen("home"); };
  const toggleTheme  = () => setTheme(t => t === "dark" ? "light" : "dark");

  const showNav   = loggedIn && screen !== "confirmation" && screen !== "login";

  return (
    <div style={{ width: "100%", minHeight: "100vh", background: "var(--outer-bg)", display: "flex", alignItems: "flex-start", justifyContent: "center" }}>
      <div
        className="screen"
        data-theme={theme}
        style={{ height: "100vh", display: "flex", flexDirection: "column", overflow: "hidden", boxShadow: "0 0 60px rgba(0,0,0,0.6)" }}
      >
        <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
          {screen === "login" && <LoginScreen onLogin={handleLogin} />}
          {screen === "home" && loggedIn && (
            <HomeScreen setScreen={setScreen} setViewProduct={setViewProduct} theme={theme} toggleTheme={toggleTheme} />
          )}
          {screen === "search" && loggedIn && (
            <SearchScreen setScreen={setScreen} setViewProduct={setViewProduct} />
          )}
          {screen === "product" && loggedIn && viewProduct && (
            <ProductScreen product={viewProduct} setScreen={setScreen} />
          )}
          {screen === "messages" && loggedIn && (
            <MessagesScreen />
          )}
          {screen === "profile" && loggedIn && (
            <ProfileScreen setScreen={setScreen} />
          )}
          {screen === "cart" && loggedIn && (
            <CartScreen setScreen={setScreen} cart={cart} setCart={setCart} />
          )}
          {screen === "checkout" && loggedIn && (
            <CheckoutScreen setScreen={setScreen} cart={cart} setCart={setCart} />
          )}
          {screen === "confirmation" && loggedIn && (
            <ConfirmationScreen setScreen={setScreen} />
          )}
          {screen === "newListing" && loggedIn && (
            <NewListingScreen setScreen={setScreen} />
          )}
          {screen === "sellerHub" && loggedIn && (
            <SellerScreen setScreen={setScreen} setViewProduct={setViewProduct} />
          )}
        </div>
        {showNav && <BottomNav screen={screen} setScreen={setScreen} />}
      </div>
    </div>
  );
}
