with Ada.Unchecked_Deallocation;

package body Files.Shared_Bytes is

   procedure Free is new Ada.Unchecked_Deallocation (Payload, Payload_Access);

   function To_Shared (Value : Files.Types.Byte_Vectors.Vector) return Bytes is
   begin
      if Value.Is_Empty then
         return Empty;
      end if;
      --  A new Atomic_Counter starts at one: this value is the only holder.
      return (Ada.Finalization.Controlled with Ref => new Payload'(Count => <>, Data => Value));
   end To_Shared;

   function To_Vector (Value : Bytes) return Files.Types.Byte_Vectors.Vector is
   begin
      if Value.Ref = null then
         return Files.Types.Byte_Vectors.Empty_Vector;
      end if;
      return Value.Ref.Data;
   end To_Vector;

   function Length (Value : Bytes) return Natural is
     (if Value.Ref = null then 0 else Natural (Value.Ref.Data.Length));

   overriding function "=" (Left, Right : Bytes) return Boolean is
      use type Files.Types.Byte_Vectors.Vector;
   begin
      if Left.Ref = Right.Ref then
         return True;
      elsif Left.Ref = null or else Right.Ref = null then
         return Length (Left) = 0 and then Length (Right) = 0;
      end if;
      return Left.Ref.Data = Right.Ref.Data;
   end "=";

   overriding procedure Adjust (Object : in out Bytes) is
   begin
      if Object.Ref /= null then
         System.Atomic_Counters.Increment (Object.Ref.Count);
      end if;
   end Adjust;

   overriding procedure Finalize (Object : in out Bytes) is
      Ref : Payload_Access := Object.Ref;
   begin
      --  Finalize may run more than once on one object; clear first.
      Object.Ref := null;
      if Ref /= null and then System.Atomic_Counters.Decrement (Ref.Count) then
         Free (Ref);
      end if;
   end Finalize;

end Files.Shared_Bytes;
