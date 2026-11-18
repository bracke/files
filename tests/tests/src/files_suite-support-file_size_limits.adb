with Interfaces.C;

package body Files_Suite.Support.File_Size_Limits is

   --  SIGXFSZ, the same number on Linux and macOS.
   File_Size_Signal : constant Interfaces.C.int := 25;
   Ignore           : constant System.Address := System'To_Address (1);

   function C_Signal (Item : Interfaces.C.int; Handler : System.Address) return System.Address
     with Import, Convention => C, External_Name => "signal";

   function Lower (Item : in out Cap; Bytes : Hostkit.Limits.Amount) return Boolean is
   begin
      Lift (Item);
      if not Hostkit.Limits.Limit (Hostkit.Limits.File_Size, Hostkit.Limits.Soft, Item.Old_Soft) then
         return False;
      end if;
      Item.Old_Signal := C_Signal (File_Size_Signal, Ignore);
      Item.Lowered := True;
      if not Hostkit.Limits.Set_Limit (Hostkit.Limits.File_Size, Hostkit.Limits.Soft, Bytes) then
         Lift (Item);
         return False;
      end if;
      return True;
   end Lower;

   procedure Lift (Item : in out Cap) is
      Restored : Boolean;
      Previous : System.Address;
      pragma Unreferenced (Restored, Previous);
   begin
      if Item.Lowered then
         Item.Lowered := False;
         Restored := Hostkit.Limits.Set_Limit (Hostkit.Limits.File_Size, Hostkit.Limits.Soft, Item.Old_Soft);
         Previous := C_Signal (File_Size_Signal, Item.Old_Signal);
      end if;
   end Lift;

   overriding procedure Finalize (Item : in out Cap) is
   begin
      Lift (Item);
   end Finalize;

end Files_Suite.Support.File_Size_Limits;
