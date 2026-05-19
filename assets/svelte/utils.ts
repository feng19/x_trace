import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
	return twMerge(clsx(inputs));
}

export type WithElementRef<T, El extends HTMLElement = HTMLElement> = T & {
	ref?: El | null;
};

type Primitive<T> = Omit<T, "children" | "child">;

export type WithoutChildrenOrChild<T> = Primitive<T>;

export type WithoutChild<T> = Omit<T, "child">;

export type WithoutChildren<T> = Omit<T, "children">;
