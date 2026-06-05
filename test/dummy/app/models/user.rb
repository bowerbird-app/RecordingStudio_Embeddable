class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def RS_accessible
    return self[:RS_accessible] if has_attribute?(:RS_accessible)
    return self[:rs_accessible] if has_attribute?(:rs_accessible)

    true
  end
end
