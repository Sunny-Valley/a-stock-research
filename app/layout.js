import "./globals.css";

export const metadata = {
  title: "A股智投 AI",
  description: "AI-powered A-Share Stock Analysis",
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh-CN">
      <body className="bg-slate-900 text-slate-100">{children}</body>
    </html>
  );
}