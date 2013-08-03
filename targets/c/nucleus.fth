\ -*- forth -*- Copyright 2013 Lars Brinkhoff

code cold \ int main (void)
  extern struct word warm_word, dp_word, SP_word, RP_word,
    data_stack_word, return_stack_word, dictionary_end_word,
    jmpbuf_word, sigint_word;
  static cell dictionary[15000];
  size_t start = (size_t)&dictionary, end;
  void signal_handler (int);
  xt_t *IP = (xt_t *)warm_word.param;
  long page_size;

  dp_word.param[0] = (cell)dictionary;
  SP_word.param[0] = (cell)(&data_stack_word.param[100]);
  RP_word.param[0] = (cell)(&return_stack_word.param[256]);
  dictionary_end_word.param[0] = (cell)dictionary + sizeof dictionary;

  siginterrupt (SIGINT, 1);
  signal (SIGINT, signal_handler);
  siginterrupt (SIGSEGV, 1);
  signal (SIGSEGV, signal_handler);

  end = start + sizeof dictionary;
  page_size = sysconf (_SC_PAGESIZE);
  start &= -page_size;
  end = (end + page_size - 1) & -page_size;
  if (mprotect ((void *)start, end - start, PROT_READ | PROT_WRITE | PROT_EXEC))
    {
      perror ("mprotect");
      return 1;
    }

  for (;;)
    {
      if (setjmp ((void *)jmpbuf_word.param))
        EXECUTE (&sigint_word);

      for (;;)
        {
          xt_t xt = NEXT_XT;
          EXECUTE (xt);
        }
    }

  return 0;
end-code

code signal_handler \ void signal_handler (int i)
  extern struct word jmpbuf_word;
  sigset_t set;
  sigemptyset (&set);
  sigaddset (&set, i);
  sigprocmask (SIG_UNBLOCK, &set, 0);
  signal (i, signal_handler);
  longjmp ((void *)jmpbuf_word.param, i);
end-code

code exit ( R: ret -- )
    IP = RPOP (xt_t *);
end-code

code dodoes ( -- addr ) ( R: -- ret )
    PUSH (word->param);
    RPUSH (IP);
    IP = (xt_t *)(word->does);
end-code

\ Possible, but slow, implementation of 0branch.
\ : select   0= dup invert swap rot nand invert rot rot nand invert + ;
\ : 0branch   r> dup cell+ swap @ rot select >r ;

code 0branch ( x -- )
    xt_t *addr = *(xt_t **)IP;
    cell x = POP (cell);
    if (!x)
      IP = addr;
    else
      IP++;
end-code

\ This works, but is too slow.
\ create 'cell   cell ,
\ variable temp
\ : (literal)   r> temp ! temp @ temp @ 'cell @ + >r @ ;

code (literal) ( -- n )
    PUSH (*(cell *)IP);
    IP++;
end-code

code ! ( x addr -- )
    cell *addr = POP (cell *);
    cell x = POP (cell);
    *addr = x;
end-code

code @ ( addr -- x )
    cell *addr = POP (cell *);
    PUSH (*addr);
end-code

\ : +   begin ?dup while 2dup xor -rot and 2* repeat ;

code + ( x y -- x+y )
    cell y = POP (cell);
    cell x = POP (cell);
    PUSH (x + y);
end-code

\ This works, but is too slow.
\ : >r   r@ rp@ -4 + rp! rp@ ! rp@ 4 + ! ;

code >r  ( x -- ) ( R: -- x )
    cell x = POP (cell);
    RPUSH (x);
end-code

\ This works, but is too slow.
\ : r>   rp@ 4 + @ r@ rp@ 4 + rp! rp@ ! ;

code r> ( -- x ) ( R: x -- )
    cell x = RPOP (cell);
    PUSH (x);
end-code

code nand ( x y -- ~(x&y) )
    cell y = POP (cell);
    cell x = POP (cell);
    PUSH (~(x & y));
end-code

code c! ( c addr -- )
    char *addr = POP (char *);
    cell c = POP (cell);
    *addr = c;
end-code

code c@ ( addr -- c )
    unsigned char *addr = POP (unsigned char *);
    PUSH (*addr);
end-code

code emit ( c -- )
    cell c = POP (cell);
    putchar (c);
end-code

code bye ( ... -- <no return> )
    exit (0);
end-code

code close-file ( fileid -- ior )
    FILE *fileid = POP (FILE *);
    PUSH (fclose (fileid) == 0 ? 0 : errno);
end-code

code open-file ( addr n mode -- fileid ior )
    char *mode = POP (char *);
    int n = POP (cell);
    char *addr = POP (char *);
    char *name = malloc (n + 1);
    FILE *fileid;

    memcpy (name, addr, n);
    name[n] = 0;
    fileid = fopen (name, mode);
    PUSH (fileid);
    PUSH (fileid == 0 ? errno : 0 );
end-code

code read-file ( addr n1 fileid -- n2 ior )
    FILE *fileid = POP (FILE *);
    if (fileid == 0)
      fileid = stdin;
    cell n1 = POP (cell);
    char *addr = POP (char *);
    size_t n2;
    n2 = fread (addr, 1, n1, fileid);
    PUSH (n2);
    PUSH (ferror (fileid) ? errno : 0);
end-code
