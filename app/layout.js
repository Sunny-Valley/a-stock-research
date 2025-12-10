import "./globals.css";

export const metadata = {
  title: "StockAI Pro - Quant",
  description: "Professional A-Share Quantitative Analysis",
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh-CN">
      <body className="antialiased text-slate-900 bg-[#f5f5f7]">{children}</body>
    </html>
  );
}
