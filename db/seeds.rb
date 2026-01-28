# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Creating tea lots..."

tea_lots_data = [
  { lot_code: "TL-2024-001", origin: "鹿児島", variety: "やぶきた", harvest_date: "2024-05-15", quantity_kg: 120.5, status: "shipped" },
  { lot_code: "TL-2024-002", origin: "静岡", variety: "さやまかおり", harvest_date: "2024-05-18", quantity_kg: 98.3, status: "processing" },
  { lot_code: "TL-2024-003", origin: "京都", variety: "玉露", harvest_date: "2024-05-20", quantity_kg: 45.7, status: "processing" },
  { lot_code: "TL-2024-004", origin: "福岡", variety: "ほうじ茶", harvest_date: "2024-05-22", quantity_kg: 156.2, status: "received" },
  { lot_code: "TL-2024-005", origin: "宮崎", variety: "煎茶", harvest_date: "2024-05-25", quantity_kg: 87.9, status: "shipped" }
]

tea_lots = tea_lots_data.map do |lot_data|
  TeaLot.find_or_create_by!(lot_code: lot_data[:lot_code]) do |lot|
    lot.assign_attributes(lot_data)
  end
end

puts "Creating process events..."

process_events_data = [
  # Events for TL-2024-001
  { tea_lot: tea_lots[0], event_type: "steaming", occurred_at: "2024-05-16 09:00", note: "蒸し工程完了" },
  { tea_lot: tea_lots[0], event_type: "rolling", occurred_at: "2024-05-16 11:30", note: "揉み工程完了" },
  { tea_lot: tea_lots[0], event_type: "drying", occurred_at: "2024-05-16 14:00", note: "乾燥工程完了" },
  { tea_lot: tea_lots[0], event_type: "packing", occurred_at: "2024-05-17 10:00", note: "包装完了" },
  
  # Events for TL-2024-002
  { tea_lot: tea_lots[1], event_type: "steaming", occurred_at: "2024-05-19 08:30", note: "蒸し工程完了" },
  { tea_lot: tea_lots[1], event_type: "rolling", occurred_at: "2024-05-19 11:00", note: "揉み工程完了" },
  { tea_lot: tea_lots[1], event_type: "drying", occurred_at: "2024-05-19 13:30", note: "乾燥工程完了" },
  
  # Events for TL-2024-003
  { tea_lot: tea_lots[2], event_type: "steaming", occurred_at: "2024-05-21 09:15", note: "蒸し工程完了" },
  { tea_lot: tea_lots[2], event_type: "rolling", occurred_at: "2024-05-21 12:00", note: "揉み工程完了" },
  { tea_lot: tea_lots[2], event_type: "drying", occurred_at: "2024-05-21 15:00", note: "乾燥工程完了" },
  { tea_lot: tea_lots[2], event_type: "packing", occurred_at: "2024-05-22 09:00", note: "包装完了" },
  
  # Events for TL-2024-004
  { tea_lot: tea_lots[3], event_type: "steaming", occurred_at: "2024-05-23 08:00", note: "蒸し工程完了" },
  { tea_lot: tea_lots[3], event_type: "rolling", occurred_at: "2024-05-23 10:30", note: "揉み工程完了" },
  
  # Events for TL-2024-005
  { tea_lot: tea_lots[4], event_type: "steaming", occurred_at: "2024-05-26 09:30", note: "蒸し工程完了" },
  { tea_lot: tea_lots[4], event_type: "rolling", occurred_at: "2024-05-26 12:00", note: "揉み工程完了" },
  { tea_lot: tea_lots[4], event_type: "drying", occurred_at: "2024-05-26 14:30", note: "乾燥工程完了" },
  { tea_lot: tea_lots[4], event_type: "packing", occurred_at: "2024-05-27 08:30", note: "包装完了" }
]

process_events_data.each do |event_data|
  ProcessEvent.find_or_create_by!(
    tea_lot: event_data[:tea_lot],
    event_type: event_data[:event_type],
    occurred_at: event_data[:occurred_at]
  ) do |event|
    event.note = event_data[:note]
  end
end

puts "Creating shipments..."

shipments_data = [
  # Shipments for TL-2024-001
  { tea_lot: tea_lots[0], destination: "東京卸売市場", shipped_at: "2024-05-18", quantity_kg: 60.5 },
  { tea_lot: tea_lots[0], destination: "大阪茶業市場", shipped_at: "2024-05-20", quantity_kg: 60.0 },
  
  # Shipments for TL-2024-002
  { tea_lot: tea_lots[1], destination: "名古屋茶流通センター", shipped_at: "2024-05-24", quantity_kg: 98.3 },
  
  # Shipments for TL-2024-005
  { tea_lot: tea_lots[4], destination: "福岡茶業市場", shipped_at: "2024-05-28", quantity_kg: 45.0 },
  { tea_lot: tea_lots[4], destination: "熊本茶卸売", shipped_at: "2024-05-30", quantity_kg: 42.9 }
]

shipments_data.each do |shipment_data|
  Shipment.find_or_create_by!(
    tea_lot: shipment_data[:tea_lot],
    destination: shipment_data[:destination],
    shipped_at: shipment_data[:shipped_at]
  ) do |shipment|
    shipment.quantity_kg = shipment_data[:quantity_kg]
  end
end

puts "Seed data created successfully!"
puts "Tea lots: #{TeaLot.count}"
puts "Process events: #{ProcessEvent.count}"
puts "Shipments: #{Shipment.count}"
