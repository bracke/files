with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Files.Types;

--  The value types Files.File_System's results are made of, in a leaf
--  package of their own so a unit that only holds such a value (the window
--  model) need not depend on the filesystem layer. Clients name them here:
--  Files.File_System does not re-export them.
package Files.File_System_Types is
   subtype UString is Files.Types.UString;

   --  Whether a path names a directory that can be shown.
   type Path_Status is
     (Path_Valid,
      Path_Missing,
      Path_Inaccessible);

   --  A path checked as a directory to show: its status, the directory it
   --  names when valid, and the message key when not.
   type Path_Result is record
      Status         : Path_Status := Path_Missing;
      Directory_Path : UString;
      Error_Key      : UString;
   end record;

   --  What a directory held when it was read, to tell later whether it
   --  changed (Same_State). Taken is False for a signature read from nothing
   --  (Unknown_Signature, and every default): it records no state, so it
   --  never matches another, nor itself.
   type Directory_Signature is record
      Path               : UString;
      Taken              : Boolean := False;
      Exists             : Boolean := False;
      Entry_Count        : Natural := 0;
      Entry_State_Checksum : Natural := 0;
      Latest_Modified    : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Latest_Modified_Known : Boolean := False;
   end record;

   --  The signature of a listing not read from the directory (search
   --  results, items handed in) or one that could not be signed: the next
   --  check of Path reads it again.
   --
   --  @param Path The directory it stands for.
   --  @return A signature that was not taken.
   function Unknown_Signature (Path : String := "") return Directory_Signature is
     ((Path => Ada.Strings.Unbounded.To_Unbounded_String (Path), others => <>));

   --  Whether two signatures were both taken and record the same state. An
   --  unknown signature is the same as nothing, itself included.
   --
   --  @param Left One signature.
   --  @param Right The other.
   --  @return True when nothing changed between them.
   function Same_State (Left, Right : Directory_Signature) return Boolean is
     (Left.Taken
      and then Right.Taken
      and then Ada.Strings.Unbounded."=" (Left.Path, Right.Path)
      and then Left.Exists = Right.Exists
      and then Left.Entry_Count = Right.Entry_Count
      and then Left.Entry_State_Checksum = Right.Entry_State_Checksum
      and then Left.Latest_Modified_Known = Right.Latest_Modified_Known
      and then
        (not Left.Latest_Modified_Known
         or else not Right.Latest_Modified_Known
         or else Ada.Calendar."=" (Left.Latest_Modified, Right.Latest_Modified)));

   --  Whether a drop copies its sources or moves them.
   type Drop_Import_Mode is
     (Drop_Copy,
      Drop_Move);

   --  Recursive directory-size measurement. Total_Bytes sums the sizes of all
   --  descendant regular files; File_Count counts those files and Item_Count
   --  counts every visited entry (files plus directories). Capped is True when
   --  the walk stopped early against the entry-count or depth guard, so the
   --  totals are a lower bound. Available is False when the root was missing or
   --  unreadable.
   type Directory_Size_Result is record
      Available   : Boolean := False;
      Total_Bytes : Long_Long_Integer := 0;
      File_Count  : Natural := 0;
      Item_Count  : Natural := 0;
      Capped      : Boolean := False;
   end record;

   --  What a root entry stands for, which decides its label and icon.
   type Root_Kind is
     (Root_Filesystem,
      Root_Home,
      Root_Current,
      Root_Mount,
      Root_User_Mount,
      Root_Network_Mount,
      Root_Windows_Drive,
      Root_Favorite);

   --  One place the root selector offers: a filesystem root, home, a mount,
   --  a drive or a favorite.
   type Root_Entry is record
      Path  : UString;
      --  A localization key ("root.home", "root.mount") or literal text.
      Label : UString;
      --  The {name} a key's pattern takes (a mount's leaf name), or empty.
      Name  : UString;
      --  A detail shown after the label (a mount's filesystem type), or empty.
      Detail : UString;
      Kind  : Root_Kind := Root_Filesystem;
      Volume_Name : UString;
      Removable   : Boolean := False;
   end record;

   --  The root selector's entries, in the order offered.
   package Root_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Root_Entry);

   --  Free and total space of a volume (the one holding the window's
   --  current directory).
   type Volume_Space is record
      Known       : Boolean := False;
      Free_Bytes  : Long_Long_Integer := 0;
      Total_Bytes : Long_Long_Integer := 0;
   end record;

   --  Which numeric account an owner name belongs to: a user id or a group id.
   type Account_Kind is (User_Account, Group_Account);

end Files.File_System_Types;
