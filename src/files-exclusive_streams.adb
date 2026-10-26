with Ada.IO_Exceptions;

with Files.Private_Directories;

package body Files.Exclusive_Streams is
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.OS_Lib.File_Descriptor;

   procedure Flush (Stream : in out Output_Stream);

   procedure Create (Stream : in out Output_Stream; Path : String) is
   begin
      if Is_Open (Stream) then
         raise Ada.IO_Exceptions.Status_Error;
      end if;
      Stream.Length := 0;
      Stream.Pending := 0;
      Stream.Descriptor :=
        GNAT.OS_Lib.Create_New_File (Path, GNAT.OS_Lib.Binary);
      if Stream.Descriptor = GNAT.OS_Lib.Invalid_FD then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
      Files.Private_Directories.Make_File_Private (Stream.Descriptor);
   exception
      when others =>
         Close_Safely (Stream);
         raise;
   end Create;

   procedure Close (Stream : in out Output_Stream) is
      Closed : Boolean;
   begin
      if not Is_Open (Stream) then
         return;
      end if;
      begin
         Flush (Stream);
      exception
         when others =>
            Close_Safely (Stream);
            raise Ada.IO_Exceptions.Use_Error;
      end;
      GNAT.OS_Lib.Close (Stream.Descriptor, Closed);
      Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
      if not Closed then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
   end Close;

   procedure Close_Safely (Stream : in out Output_Stream) is
   begin
      Stream.Pending := 0;
      if Is_Open (Stream) then
         GNAT.OS_Lib.Close (Stream.Descriptor);
         Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
      end if;
   exception
      when others =>
         Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
   end Close_Safely;

   function Is_Open (Stream : Output_Stream) return Boolean is
     (Stream.Descriptor /= GNAT.OS_Lib.Invalid_FD);

   function Size (Stream : Output_Stream) return Long_Long_Integer is
     (Stream.Length);

   overriding procedure Read
     (Stream : in out Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Stream, Item, Last);
   begin
      raise Program_Error;
   end Read;

   --  Write all of Item to the descriptor.
   procedure Write_Through
     (Stream : Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
      Next : Ada.Streams.Stream_Element_Offset := Item'First;
      Written : Integer;
   begin
      while Next <= Item'Last loop
         declare
            Remaining : constant Ada.Streams.Stream_Element_Offset :=
              Item'Last - Next + 1;
            Requested : constant Integer := Integer
              (Ada.Streams.Stream_Element_Offset'Min
                 (Remaining,
                  Ada.Streams.Stream_Element_Offset (Integer'Last)));
         begin
            Written := GNAT.OS_Lib.Write
              (Stream.Descriptor, Item (Next)'Address, Requested);
         end;
         if Written <= 0 then
            raise Ada.IO_Exceptions.Use_Error;
         end if;
         Next := Next + Ada.Streams.Stream_Element_Offset (Written);
      end loop;
   end Write_Through;

   procedure Flush (Stream : in out Output_Stream) is
   begin
      if Stream.Pending > 0 then
         Write_Through (Stream, Stream.Block (1 .. Stream.Pending));
         Stream.Pending := 0;
      end if;
   end Flush;

   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
   begin
      if not Is_Open (Stream)
        or else Long_Long_Integer (Item'Length) >
          Long_Long_Integer'Last - Stream.Length
      then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
      if Item'Length > Block_Size - Stream.Pending then
         Flush (Stream);
      end if;
      if Item'Length >= Block_Size then
         Write_Through (Stream, Item);
      else
         Stream.Block (Stream.Pending + 1 .. Stream.Pending + Item'Length) := Item;
         Stream.Pending := Stream.Pending + Item'Length;
      end if;
      Stream.Length := Stream.Length + Long_Long_Integer (Item'Length);
   end Write;
end Files.Exclusive_Streams;
