import pino from 'pino';

/**
 * 应用日志配置
 * - 生产环境：JSON 格式，便于日志收集系统解析
 * - 开发环境：美化格式，便于阅读
 */
export const logger = pino({
  // 日志级别：生产环境 info，开发环境 debug
  level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
  
  // 基础配置
  base: {
    pid: process.pid,
  },
  
  // 时间戳格式
  timestamp: pino.stdTimeFunctions.isoTime,
  
  // 开发环境使用美化输出
  transport: process.env.NODE_ENV !== 'production'
    ? {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'HH:MM:ss Z',
          ignore: 'pid',
        },
      }
    : undefined,
});

/**
 * 创建带上下文的子日志器
 * @param context 上下文信息（如模块名、用户ID等）
 * @returns 子日志器
 * @example
 * const dbLogger = createChildLogger({ module: 'database' });
 * dbLogger.info('连接成功');
 * // 输出: {"module":"database","msg":"连接成功",...}
 */
export function createChildLogger(context: Record<string, unknown>) {
  return logger.child(context);
}

export default logger;
