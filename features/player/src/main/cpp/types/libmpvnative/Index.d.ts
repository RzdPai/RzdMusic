/*
 * Copyright (c) 2026 RzdPai
 *
 * libmpvnative 的类型声明（与 ../mpv_bridge.cpp 一一对应）。
 * 全部是**同步**调用：位置/时长由 ArkTS 侧每 250ms 轮询 getProperty() 获取。
 */
export const create: () => boolean;
export const isAvailable: () => boolean;
export const command: (args: string[]) => boolean;
export const setProperty: (name: string, value: string) => boolean;
export const getProperty: (name: string) => string;
export const destroy: () => void;