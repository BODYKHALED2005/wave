from db.database import SessionLocal, Child, init_db

def seed_db():
    init_db()
    db = SessionLocal()
    
    # Check if we already seeded
    if db.query(Child).first():
        db.close()
        print("Database already seeded")
        return
        
    children = [
        Child(id="child_lina", name="Lina", age_label="4y 2m", device_id="WM-2048", has_assigned_device=True),
        Child(id="child_omar", name="Omar", age_label="7y 1m", device_id="WM-1781", has_assigned_device=True)
    ]
    
    db.add_all(children)
    db.commit()
    db.close()
    print("Database seeded successfully!")

if __name__ == "__main__":
    seed_db()
