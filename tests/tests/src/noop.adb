procedure Noop is
begin
   --  A program that does nothing and succeeds.
   --
   --  The suite needs a real executable to launch for the open-action tests, and
   --  borrowing one from the host does not travel: /bin/true is absent on macOS,
   --  absent again on Windows, and every Windows stand-in tried either refused
   --  its arguments or -- in cmd.exe's case -- opened an interactive shell and
   --  waited for input until the CI runner gave up. Shipping the program removes
   --  the guesswork: it ignores whatever it is handed and exits zero.
   null;
end Noop;
