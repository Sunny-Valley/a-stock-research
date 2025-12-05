import "./globals.css";

export const metadata = {
  title: "A股智投 AI",
  description: "极简主义 A股 AI 分析工具",
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh-CN">
      {/* 核心改变：背景改为极浅的灰色 (gray-50)，文字改为深灰 (gray-900) */}
      <body className="bg-[#f5f5f7] text-gray-900 antialiased selection:bg-blue-500 selection:text-white">
        {children}
      </body>
    </html>
  );
}