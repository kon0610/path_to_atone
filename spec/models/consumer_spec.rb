require 'rails_helper'

RSpec.describe Consumer, type: :model do
  describe 'バリデーションのテスト' do
    let(:consumer) do
      Consumer.new(
        full_name: "山田 太郎",
        age: 30,
        phone_number: "09012345678",
        member_registration_datetime: Time.now,
        member_code: 12345
      )
    end

    context '全ての属性が正しい場合' do
      it '有効であること' do
        expect(consumer).to be_valid
      end
    end

    context 'full_nameのバリデーション' do
      it 'full_nameが空の場合、無効であること' do
        consumer.full_name = nil
        expect(consumer).to_not be_valid
        expect(consumer.errors[:full_name]).to include("can't be blank")
      end
    end

    context 'ageのバリデーション' do
      it 'ageが空の場合、無効であること' do
        consumer.age = nil
        expect(consumer).to_not be_valid
        expect(consumer.errors[:age]).to include("can't be blank")
      end

      it 'ageが負の値の場合、無効であること' do
        consumer.age = -1
        expect(consumer).to_not be_valid
        expect(consumer.errors[:age]).to include("must be greater than or equal to 0")
      end

      it 'ageが整数でない場合、無効であること' do
        consumer.age = 30.5
        expect(consumer).to_not be_valid
        expect(consumer.errors[:age]).to include("must be an integer")
      end
    end

    context 'phone_numberのバリデーション' do
      it 'phone_numberが空の場合、無効であること' do
        consumer.phone_number = nil
        expect(consumer).to_not be_valid
        expect(consumer.errors[:phone_number]).to include("can't be blank")
      end

      it 'phone_numberが10桁未満の場合、無効であること' do
        consumer.phone_number = "123456789"
        expect(consumer).to_not be_valid
        expect(consumer.errors[:phone_number]).to include("must be a valid phone number")
      end

      it 'phone_numberが12桁以上の場合、無効であること' do
        consumer.phone_number = "123456789012"
        expect(consumer).to_not be_valid
        expect(consumer.errors[:phone_number]).to include("must be a valid phone number")
      end
    end

    context 'member_registration_datetimeのバリデーション' do
      it 'member_registration_datetimeが空の場合、無効であること' do
        consumer.member_registration_datetime = nil
        expect(consumer).to_not be_valid
        expect(consumer.errors[:member_registration_datetime]).to include("can't be blank")
      end
    end

    context 'member_codeのバリデーション' do
      it 'member_codeが空の場合、無効であること' do
        consumer.member_code = nil
        expect(consumer).to_not be_valid
        expect(consumer.errors[:member_code]).to include("can't be blank")
      end

      it 'member_codeが重複している場合、無効であること' do
        Consumer.create!(
          full_name: "山田 太郎",
          age: 30,
          phone_number: "09012345678",
          member_registration_datetime: Time.now,
          member_code: 12345
        )
        duplicate_consumer = Consumer.new(member_code: 12345)
        expect(duplicate_consumer).to_not be_valid
        expect(duplicate_consumer.errors[:member_code]).to include("has already been taken")

      end
    end
  end
end
