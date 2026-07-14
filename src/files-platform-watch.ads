private with Ada.Strings.Unbounded;
private with Interfaces.C;

package Files.Platform.Watch is

   --  Native directory-change notification.
   --
   --  The body is selected per platform by the project file (Source_Dirs =
   --  "src/platform/" & <host OS>): Linux uses inotify, macOS uses kqueue's
   --  EVFILT_VNODE, and Windows uses FindFirstChangeNotification. The
   --  unsupported stub never becomes active.
   --
   --  Every platform is allowed to fail quietly. A watch that cannot be
   --  established simply stays inactive, and the caller falls back to polling
   --  the directory on a timer -- so a missing or exhausted notification
   --  facility costs responsiveness, never correctness.

   type Watch_State is private;

   procedure Watch_Path (State : in out Watch_State; Path : String);
   --  Point the watch at Path, releasing any directory it was watching before.
   --  Watching the same path twice running is a no-op, so this is cheap to call
   --  every frame. An empty Path releases the watch.
   --  @param State the watch
   --  @param Path  the directory to watch

   procedure Release (State : in out Watch_State);
   --  Drop the watch and its native handles.
   --  @param State the watch

   function Poll (State : in out Watch_State) return Boolean;
   --  Consume any pending change notifications without blocking.
   --  @param State the watch
   --  @return True when the watched directory changed since the last call

   function Is_Active (State : Watch_State) return Boolean;
   --  Whether a native watch is currently established.
   --  @param State the watch
   --  @return True when the platform is delivering notifications

   function Event_Count (State : Watch_State) return Natural;
   --  How many notifications this watch has consumed, for diagnostics.
   --  @param State the watch
   --  @return the running count

private

   --  The two handles mean whatever the platform body needs. On Linux they are
   --  the inotify descriptor and the watch descriptor; on macOS the kqueue and
   --  the open directory; on Windows the change-notification handle alone.
   use type Interfaces.C.ptrdiff_t;

   Unset : constant Interfaces.C.ptrdiff_t := -1;

   type Watch_State is record
      Handle : Interfaces.C.ptrdiff_t := Unset;
      Extra  : Interfaces.C.ptrdiff_t := Unset;
      Path   : Ada.Strings.Unbounded.Unbounded_String;
      Events : Natural := 0;
   end record;

end Files.Platform.Watch;
