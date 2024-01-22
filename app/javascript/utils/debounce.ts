export const debounce = (func: Function, delay: number) => {
  let timer: ReturnType<typeof setTimeout>;

  return function() {
    const context = this;
    const args = arguments;
    clearTimeout(timer);

    timer = setTimeout(() => func.apply(context, args), delay);
  }
}
